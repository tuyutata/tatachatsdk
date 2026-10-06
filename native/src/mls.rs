use std::{
    cell::RefCell,
    collections::{HashMap, HashSet},
    ffi::CStr,
    fs,
    os::raw::c_char,
    path::{Path, PathBuf},
};

use openmls::{
    prelude::{
        tls_codec::{Deserialize as TlsDeserialize, Serialize as TlsSerialize},
        BasicCredential, Capabilities, Ciphersuite, Credential, CredentialWithKey, ExtensionType,
        Extensions, GroupId, KeyPackage, KeyPackageBundle, KeyPackageIn, Lifetime, MlsGroup,
        MlsGroupCreateConfig, MlsMessageBodyIn, MlsMessageIn, ProcessedMessageContent,
        ProtocolMessage, ProtocolVersion, StagedWelcome,
    },
    storage::OpenMlsProvider as OpenMlsStorageProvider,
};
use openmls_basic_credential::SignatureKeyPair;
use openmls_memory_storage::MemoryStorage;
#[cfg(test)]
use openmls_rust_crypto::OpenMlsRustCrypto;
use openmls_rust_crypto::RustCrypto;
#[cfg(test)]
use openmls_traits::types::SignatureScheme;
use openmls_traits::{signatures::Signer, OpenMlsProvider as OpenMlsTraitsProvider};
use serde::{Deserialize, Serialize};
use serde_json::json;

const GMB_MLS_CIPHERSUITE: Ciphersuite = Ciphersuite::MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519;
const ERROR_STORAGE_READ: &str = "CHAT_MLS_STORAGE_READ_FAILED";
const ERROR_STATE_INVALID: &str = "CHAT_MLS_STATE_INVALID";
const ERROR_SIGNER_MISSING: &str = "CHAT_MLS_SIGNER_MISSING";
const MAX_PENDING_RESULTS: usize = 256;
const RECEIPT_LIFETIME_MILLIS: u64 = 7 * 24 * 60 * 60 * 1000;
/// 错误只携带稳定阶段码，禁止包含状态中的秘密。
fn state_error(code: &str, message: impl std::fmt::Display) -> String {
    format!("{code}:{message}")
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct CreateKeyPackageRequest {
    user_id: String,
    device_id: String,
    state_store_dir: String,
    message_id: String,
    /// 生成 RFC 9420 last-resort KeyPackage；服务端只保留每个 用户身份/设备一枚。
    #[serde(default)]
    last_resort: bool,
}

#[cfg(test)]
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct TwoPartySmokeRequest {
    plaintext: String,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct IdentityRequest {
    state_store_dir: String,
    user_id: String,
    action: String,
}

#[derive(Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct DeviceRecord {
    user_id: String,
    device_id: String,
    public_key: String,
}

/// 请求结果与MLS状态同一提交，幂等标识复用现有message_id。
#[derive(Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct CommittedResult {
    request: serde_json::Value,
    result: serde_json::Value,
    acknowledged: bool,
    committed_at_millis: u64,
    acknowledged_at_millis: Option<u64>,
}
#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct MlsSnapshot {
    device: DeviceRecord,
    values: HashMap<String, String>,
    results: HashMap<String, CommittedResult>,
    pending_inbound: Vec<serde_json::Value>,
    receipts: HashMap<String, Vec<String>>,
}
struct MlsProvider {
    crypto: RustCrypto,
    storage: MemoryStorage,
    device: DeviceRecord,
    results: RefCell<HashMap<String, CommittedResult>>,
    pending_inbound: RefCell<Vec<serde_json::Value>>,
    receipts: RefCell<HashMap<String, Vec<String>>>,
}

impl OpenMlsTraitsProvider for MlsProvider {
    type CryptoProvider = RustCrypto;
    type RandProvider = RustCrypto;
    type StorageProvider = MemoryStorage;

    fn storage(&self) -> &Self::StorageProvider {
        &self.storage
    }

    fn crypto(&self) -> &Self::CryptoProvider {
        &self.crypto
    }

    fn rand(&self) -> &Self::RandProvider {
        &self.crypto
    }
}

/// 生成真实 OpenMLS KeyPackage，并以 JSON 返回 hex。
///
/// # Safety
/// - `request_json` 必须是合法 UTF-8 C 字符串。
/// - 返回字符串必须由 `tatachat_sdk_free_string` 释放。
#[no_mangle]
pub unsafe extern "C" fn tatachat_sdk_mls_create_key_package_json(
    request_json: *const c_char,
    error_out: *mut *mut c_char,
) -> *mut c_char {
    match create_key_package_json(request_json) {
        Ok(value) => crate::string_into_raw(value, error_out),
        Err(message) => {
            crate::set_error(error_out, &message);
            std::ptr::null_mut()
        }
    }
}

/// 显式初始化或读取MLS公开身份；读取路径永不生成密钥。
/// # Safety
/// 输入必须是UTF-8 C字符串，返回字符串由SDK释放。
#[no_mangle]
pub unsafe extern "C" fn tatachat_sdk_mls_identity_json(
    input: *const c_char,
    error_out: *mut *mut c_char,
) -> *mut c_char {
    match identity_json(input) {
        Ok(value) => crate::string_into_raw(value, error_out),
        Err(message) => {
            crate::set_error(error_out, &message);
            std::ptr::null_mut()
        }
    }
}
fn identity_json(input: *const c_char) -> Result<String, String> {
    let request: IdentityRequest = parse_request(input)?;
    require_identity_component(&request.user_id)?;
    let dir = Path::new(&request.state_store_dir);
    let _lock = lock_store(dir)?;
    let provider = match request.action.as_str() {
        "initialize" => {
            if storage_path(dir).exists() {
                return Err(state_error(ERROR_STATE_INVALID, "身份已存在，必须读取"));
            }
            let storage = MemoryStorage::default();
            let signer = SignatureKeyPair::new(GMB_MLS_CIPHERSUITE.signature_algorithm())
                .map_err(|_| state_error(ERROR_STATE_INVALID, "MLS签名身份生成失败"))?;
            signer
                .store(&storage)
                .map_err(|_| state_error(ERROR_STATE_INVALID, "MLS签名身份保存失败"))?;
            let public = hex::encode(signer.to_public_vec());
            let provider = MlsProvider {
                crypto: RustCrypto::default(),
                storage,
                device: DeviceRecord {
                    user_id: request.user_id.clone(),
                    device_id: public.clone(),
                    public_key: format!("0x{public}"),
                },
                results: RefCell::new(HashMap::new()),
                pending_inbound: RefCell::new(Vec::new()),
                receipts: RefCell::new(HashMap::new()),
            };
            save_provider(dir, &provider)?;
            provider
        }
        "read" => load_provider(dir)?,
        _ => return Err("MLS身份action只允许initialize/read".to_string()),
    };
    let _ = read_device_signer(&provider, &request.user_id, &provider.device.device_id)?;
    serde_json::to_string(&provider.device)
        .map_err(|_| state_error(ERROR_STATE_INVALID, "公开身份序列化失败"))
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct StoreRequest {
    state_store_dir: String,
    user_id: String,
    action: String,
    message_id: Option<String>,
    pending_inbound: Option<serde_json::Value>,
    handover_id: Option<String>,
    payload_json: Option<String>,
}
/// 处理结果确认和早到密文队列；不接收或返回私钥。
/// # Safety
/// 输入必须是UTF-8 C字符串，返回字符串由SDK释放。
#[no_mangle]
pub unsafe extern "C" fn tatachat_sdk_mls_store_json(
    input: *const c_char,
    error_out: *mut *mut c_char,
) -> *mut c_char {
    match store_json(input) {
        Ok(value) => crate::string_into_raw(value, error_out),
        Err(message) => {
            crate::set_error(error_out, &message);
            std::ptr::null_mut()
        }
    }
}
fn store_json(input: *const c_char) -> Result<String, String> {
    let request: StoreRequest = parse_request(input)?;
    let dir = Path::new(&request.state_store_dir);
    let _lock = lock_store(dir)?;
    let provider = load_provider(dir)?;
    let _ = read_device_signer(&provider, &request.user_id, &provider.device.device_id)?;
    let response = match request.action.as_str() {
        "pending_results" => {
            let mut results: Vec<_> = provider
                .results
                .borrow()
                .values()
                .filter(|r| {
                    request.message_id.as_ref().map_or(!r.acknowledged, |id| {
                        r.request["message_id"].as_str() == Some(id.as_str())
                    })
                })
                .cloned()
                .collect();
            results.sort_by_key(|r| r.committed_at_millis);
            json!({"results": results})
        }
        "acknowledge" => {
            let id = request.message_id.as_deref().ok_or("缺少message_id")?;
            require_non_empty("message_id", id)?;
            let now = now_millis()?;
            for result in provider.results.borrow_mut().values_mut() {
                if result.request["message_id"] == id {
                    result.acknowledged = true;
                    if result.acknowledged_at_millis.is_none() {
                        result.acknowledged_at_millis = Some(now);
                    }
                    if result.request.get("wire_message_hex").is_some() {
                        result.result["plaintext_hex"] = serde_json::Value::Null;
                    }
                }
            }
            save_provider(dir, &provider)?;
            json!({"ok": true})
        }
        "write_receipt" => {
            let id = request.handover_id.ok_or("缺少handover_id")?;
            let payload = request.payload_json.ok_or("缺少payload_json")?;
            if id.len() > 256 || payload.len() > 1024 * 1024 {
                return Err("交接收据超限".to_string());
            }
            let mut receipts = provider.receipts.borrow_mut();
            let records = receipts.entry(id).or_default();
            if !records.contains(&payload) {
                if records.len() >= 2 {
                    return Err("交接收据阶段超限".to_string());
                }
                records.push(payload);
            }
            drop(receipts);
            save_provider(dir, &provider)?;
            json!({"ok": true})
        }
        "read_receipt" => {
            let id = request.handover_id.ok_or("缺少handover_id")?;
            json!({"payload_json": provider.receipts.borrow().get(&id)})
        }
        "delete_receipt" => {
            let id = request.handover_id.ok_or("缺少handover_id")?;
            provider.receipts.borrow_mut().remove(&id);
            save_provider(dir, &provider)?;
            json!({"ok": true})
        }
        "queue_pending" => {
            let wire = request.pending_inbound.ok_or("缺少pending_inbound")?;
            let mut pending = provider.pending_inbound.borrow_mut();
            if !pending.contains(&wire) {
                if pending.len() >= MAX_PENDING_RESULTS {
                    return Err("MLS待处理密文队列已满".to_string());
                }
                pending.push(wire);
            }
            drop(pending);
            save_provider(dir, &provider)?;
            json!({"ok": true})
        }
        "read_pending" => json!({"pending_inbound": *provider.pending_inbound.borrow()}),
        "clear_pending" => {
            provider.pending_inbound.borrow_mut().clear();
            save_provider(dir, &provider)?;
            json!({"ok": true})
        }
        _ => return Err("MLS存储action非法".to_string()),
    };
    serde_json::to_string(&response)
        .map_err(|_| state_error(ERROR_STATE_INVALID, "存储结果序列化失败"))
}

fn create_key_package_json(request_json: *const c_char) -> Result<String, String> {
    let request: CreateKeyPackageRequest = parse_request(request_json)?;
    // 消息标识在触碰持久状态之前校验，重放仍按完整原请求复核。
    require_non_empty("message_id", &request.message_id)?;
    require_non_empty("user_id", &request.user_id)?;
    require_non_empty("device_id", &request.device_id)?;

    let state_dir = Path::new(&request.state_store_dir);
    let _lock = lock_store(state_dir)?;
    let provider = load_provider(state_dir)?;
    let (credential, signer) = read_device_signer(&provider, &request.user_id, &request.device_id)?;
    if let Some(result) = committed_response(&provider, "key_package", request_json)? {
        return Ok(result);
    }
    let bundle =
        generate_published_key_package(&provider, &signer, credential, request.last_resort)?;
    let (key_package_ref, key_package_hex, not_before_millis, not_after_millis, last_resort) =
        key_package_publication_fields(&provider, &bundle)?;
    let cipher_suite = format!("{:?}", GMB_MLS_CIPHERSUITE);
    let response = json!({
        "user_id": request.user_id,
        "device_id": request.device_id,
        // RFC 9420 KeyPackageRef 是目录去重与 Welcome 引用的唯一标识，不再生成应用编号。
        "key_package_ref": key_package_ref,
        "key_package_hex": key_package_hex,
        "cipher_suite": cipher_suite,
        // 生命周期只读取刚生成的 OpenMLS KeyPackage，不再维护第二套自定义 TTL。
        "not_before_millis": not_before_millis,
        "not_after_millis": not_after_millis,
        "last_resort": last_resort,
    });
    commit_response(state_dir, &provider, "key_package", request_json, response)
}

#[cfg(test)]
fn two_party_smoke_json(request_json: *const c_char) -> Result<String, String> {
    let request: TwoPartySmokeRequest = parse_request(request_json)?;
    require_non_empty("plaintext", &request.plaintext)?;

    let alice_provider = OpenMlsRustCrypto::default();
    let bob_provider = OpenMlsRustCrypto::default();

    let (alice_credential, alice_signer) = generate_credential(
        b"alice-wallet:alice-phone".to_vec(),
        GMB_MLS_CIPHERSUITE.signature_algorithm(),
        &alice_provider,
    )?;
    let (bob_credential, bob_signer) = generate_credential(
        b"bob-wallet:bob-phone".to_vec(),
        GMB_MLS_CIPHERSUITE.signature_algorithm(),
        &bob_provider,
    )?;
    let bob_key_package = generate_key_package(&bob_provider, &bob_signer, bob_credential)?
        .key_package()
        .clone();

    let group_config = MlsGroupCreateConfig::builder()
        .ciphersuite(GMB_MLS_CIPHERSUITE)
        .use_ratchet_tree_extension(true)
        .build();
    let group_id = GroupId::from_slice(b"gmb-im-native-smoke");
    let mut alice_group = MlsGroup::new_with_group_id(
        &alice_provider,
        &alice_signer,
        &group_config,
        group_id,
        alice_credential,
    )
    .map_err(|error| format!("创建 Alice OpenMLS group 失败: {error:?}"))?;

    let (_, welcome, _) = alice_group
        .add_members(
            &alice_provider,
            &alice_signer,
            std::slice::from_ref(&bob_key_package),
        )
        .map_err(|error| format!("添加 Bob KeyPackage 失败: {error:?}"))?;
    alice_group
        .merge_pending_commit(&alice_provider)
        .map_err(|error| format!("合并 Alice pending commit 失败: {error:?}"))?;

    let welcome_bytes = welcome
        .tls_serialize_detached()
        .map_err(|error| format!("序列化 OpenMLS Welcome 失败: {error}"))?;
    let welcome_in = MlsMessageIn::tls_deserialize_exact(welcome_bytes.clone())
        .map_err(|error| format!("反序列化 OpenMLS Welcome 失败: {error}"))?;
    let welcome = match welcome_in.extract() {
        MlsMessageBodyIn::Welcome(welcome) => welcome,
        _ => return Err("OpenMLS Welcome 类型错误".to_string()),
    };
    let mut bob_group =
        StagedWelcome::new_from_welcome(&bob_provider, group_config.join_config(), welcome, None)
            .map_err(|error| format!("Bob 处理 Welcome 失败: {error:?}"))?
            .into_group(&bob_provider)
            .map_err(|error| format!("Bob 创建 group 失败: {error:?}"))?;

    let message = alice_group
        .create_message(&alice_provider, &alice_signer, request.plaintext.as_bytes())
        .map_err(|error| format!("创建 OpenMLS application message 失败: {error:?}"))?;
    let message_bytes = message
        .clone()
        .tls_serialize_detached()
        .map_err(|error| format!("序列化 OpenMLS application message 失败: {error}"))?;
    let message_in = MlsMessageIn::tls_deserialize_exact(message_bytes.clone())
        .map_err(|error| format!("反序列化 OpenMLS message 失败: {error}"))?;
    let protocol_message = message_in
        .try_into_protocol_message()
        .map_err(|_| "OpenMLS message 不是 protocol message".to_string())?;
    let processed = bob_group
        .process_message(&bob_provider, protocol_message)
        .map_err(|error| format!("Bob 解密 OpenMLS message 失败: {error:?}"))?;
    let decrypted = match processed.into_content() {
        ProcessedMessageContent::ApplicationMessage(message) => {
            String::from_utf8(message.into_bytes())
                .map_err(|error| format!("OpenMLS 明文不是 UTF-8: {error}"))?
        }
        _ => return Err("OpenMLS 处理结果不是 application message".to_string()),
    };

    let response = json!({
        "plaintext": request.plaintext,
        "decrypted_plaintext": decrypted,
        "cipher_suite": format!("{:?}", GMB_MLS_CIPHERSUITE),
        "bob_key_package_hex": hex::encode(
            bob_key_package
                .tls_serialize_detached()
                .map_err(|error| format!("序列化 Bob KeyPackage 失败: {error}"))?,
        ),
        "welcome_hex": hex::encode(welcome_bytes),
        "alice_wire_message_hex": hex::encode(message_bytes),
    });
    serde_json::to_string(&response).map_err(|error| error.to_string())
}

fn parse_request<T>(request_json: *const c_char) -> Result<T, String>
where
    T: for<'de> Deserialize<'de>,
{
    if request_json.is_null() {
        return Err("request_json is null".to_string());
    }
    let request = unsafe { CStr::from_ptr(request_json) }
        .to_str()
        .map_err(|_| "request_json 不是合法 UTF-8".to_string())?;
    serde_json::from_str(request).map_err(|_| "解析request_json失败，字段或结构非法".to_string())
}

#[cfg(test)]
fn generate_credential(
    identity: Vec<u8>,
    signature_algorithm: SignatureScheme,
    provider: &impl OpenMlsStorageProvider,
) -> Result<(CredentialWithKey, SignatureKeyPair), String> {
    let credential = BasicCredential::new(identity);
    let signature_keys = SignatureKeyPair::new(signature_algorithm)
        .map_err(|error| format!("生成 OpenMLS 签名密钥失败: {error:?}"))?;
    signature_keys
        .store(provider.storage())
        .map_err(|error| format!("保存 OpenMLS 签名密钥失败: {error:?}"))?;
    Ok((
        CredentialWithKey {
            credential: credential.into(),
            signature_key: signature_keys.to_public_vec().into(),
        },
        signature_keys,
    ))
}

#[cfg(test)]
fn generate_key_package(
    provider: &impl OpenMlsStorageProvider,
    signer: &impl Signer,
    credential_with_key: CredentialWithKey,
) -> Result<KeyPackageBundle, String> {
    generate_published_key_package(provider, signer, credential_with_key, false)
}

/// 使用 OpenMLS 默认 Lifetime 生成待发布 KeyPackage；last-resort 标记由上游库写入
/// 标准扩展，应用层不仿造扩展字节。
fn generate_published_key_package(
    provider: &impl OpenMlsStorageProvider,
    signer: &impl Signer,
    credential_with_key: CredentialWithKey,
    last_resort: bool,
) -> Result<KeyPackageBundle, String> {
    let mut builder = KeyPackage::builder()
        .key_package_lifetime(Lifetime::default())
        .key_package_extensions(Extensions::empty());
    if last_resort {
        // 中文注释：遵循 OpenMLS 官方 Last Resort 用法，扩展与 LeafNode 能力必须同时声明；
        // 否则接收方会按 RFC 9420 能力校验拒绝该 KeyPackage。
        let capabilities =
            Capabilities::new(None, None, Some(&[ExtensionType::LastResort]), None, None);
        builder = builder
            .leaf_node_capabilities(capabilities)
            .mark_as_last_resort();
    }
    builder
        .build(GMB_MLS_CIPHERSUITE, provider, signer, credential_with_key)
        .map_err(|error| format!("生成 OpenMLS KeyPackage 失败: {error:?}"))
}

/// 从 KeyPackage 内嵌的标准 Lifetime 与 LastResort 扩展导出发布元数据。
fn key_package_publication_fields(
    provider: &impl OpenMlsStorageProvider,
    bundle: &KeyPackageBundle,
) -> Result<(String, String, u64, u64, bool), String> {
    let key_package = bundle.key_package();
    let lifetime = key_package.life_time();
    let key_package_hex = hex::encode(
        key_package
            .tls_serialize_detached()
            .map_err(|error| format!("序列化 OpenMLS KeyPackage 失败: {error}"))?,
    );
    Ok((
        hex::encode(
            key_package
                .hash_ref(provider.crypto())
                .map_err(|error| format!("计算 RFC 9420 KeyPackageRef 失败: {error:?}"))?
                .as_slice(),
        ),
        key_package_hex,
        lifetime.not_before().saturating_mul(1000),
        lifetime.not_after().saturating_mul(1000),
        key_package.last_resort(),
    ))
}

/// 身份、协议状态及操作结果只由SDK在系统保护目录统一读写。
fn load_provider(dir: &Path) -> Result<MlsProvider, String> {
    use base64::Engine;
    use std::io::Read;
    let path = storage_path(dir);
    require_regular_file(&path)?;
    let mut options = fs::OpenOptions::new();
    options.read(true);
    #[cfg(any(target_os = "ios", target_os = "macos"))]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.custom_flags(0x100);
    }
    #[cfg(any(target_os = "android", target_os = "linux"))]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.custom_flags(0x20000);
    }
    let mut file = options
        .open(&path)
        .map_err(|_| state_error(ERROR_STORAGE_READ, "MLS状态读取失败"))?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        if file
            .metadata()
            .map_err(|_| state_error(ERROR_STORAGE_READ, "文件权限不可读"))?
            .permissions()
            .mode()
            & 0o777
            != 0o600
        {
            return Err(state_error(ERROR_STORAGE_READ, "MLS文件权限不安全"));
        }
    }
    let mut bytes = Vec::new();
    file.read_to_end(&mut bytes)
        .map_err(|_| state_error(ERROR_STORAGE_READ, "MLS状态读取失败"))?;
    let parsed = serde_json::from_slice::<MlsSnapshot>(&bytes);
    bytes.fill(0);
    let snapshot = parsed.map_err(|_| state_error(ERROR_STATE_INVALID, "MLS状态结构损坏"))?;
    let storage = MemoryStorage::default();
    {
        let mut values = storage
            .values
            .write()
            .map_err(|_| state_error(ERROR_STATE_INVALID, "状态锁异常"))?;
        for (key, value) in snapshot.values {
            let key = base64::prelude::BASE64_STANDARD
                .decode(key)
                .map_err(|_| state_error(ERROR_STATE_INVALID, "状态键编码损坏"))?;
            let value = base64::prelude::BASE64_STANDARD
                .decode(value)
                .map_err(|_| state_error(ERROR_STATE_INVALID, "状态值编码损坏"))?;
            values.insert(key, value);
        }
    }
    Ok(MlsProvider {
        crypto: RustCrypto::default(),
        storage,
        device: snapshot.device,
        results: RefCell::new(snapshot.results),
        pending_inbound: RefCell::new(snapshot.pending_inbound),
        receipts: RefCell::new(snapshot.receipts),
    })
}
fn save_provider(dir: &Path, provider: &MlsProvider) -> Result<(), String> {
    use base64::Engine;
    let now = now_millis()?;
    // 未落库结果不丢弃；确认收据至少覆盖服务端七天投递窗口。
    provider.results.borrow_mut().retain(|_, r| {
        !r.acknowledged
            || now.saturating_sub(r.acknowledged_at_millis.unwrap_or(now))
                <= RECEIPT_LIFETIME_MILLIS
    });
    let values = provider
        .storage
        .values
        .read()
        .map_err(|_| state_error(ERROR_STATE_INVALID, "状态读锁异常"))?
        .iter()
        .map(|(k, v)| {
            (
                base64::prelude::BASE64_STANDARD.encode(k),
                base64::prelude::BASE64_STANDARD.encode(v),
            )
        })
        .collect();
    let snapshot = MlsSnapshot {
        device: provider.device.clone(),
        values,
        results: provider.results.borrow().clone(),
        pending_inbound: provider.pending_inbound.borrow().clone(),
        receipts: provider.receipts.borrow().clone(),
    };
    let mut bytes = serde_json::to_vec(&snapshot)
        .map_err(|_| state_error(ERROR_STATE_INVALID, "状态序列化失败"))?;
    let result = atomic_write(&storage_path(dir), &bytes);
    bytes.fill(0);
    result
}
fn read_device_signer(
    provider: &MlsProvider,
    user: &str,
    device: &str,
) -> Result<(CredentialWithKey, SignatureKeyPair), String> {
    require_identity_component(user)?;
    require_identity_component(device)?;
    let record = &provider.device;
    if record.user_id != user || record.device_id != device {
        return Err("CHAT_MLS_STATE_OWNER_MISMATCH:状态属于其他用户或设备".to_string());
    }
    if !record.public_key.starts_with("0x") || record.public_key.len() != 66 {
        return Err(state_error(ERROR_STATE_INVALID, "公钥结构损坏"));
    }
    let public = decode_hex_field("public_key", &record.public_key)?;
    if record.device_id != hex::encode(&public) {
        return Err(state_error(ERROR_STATE_INVALID, "设备标识与MLS公钥不一致"));
    }
    let signer = SignatureKeyPair::read(
        provider.storage(),
        &public,
        GMB_MLS_CIPHERSUITE.signature_algorithm(),
    )
    .ok_or_else(|| state_error(ERROR_SIGNER_MISSING, "签名身份缺失"))?;
    if signer.to_public_vec() != public {
        return Err(state_error(ERROR_STATE_INVALID, "公钥与签名身份不一致"));
    }
    Ok((credential_with_public_key(user, device, public), signer))
}
fn now_millis() -> Result<u64, String> {
    Ok(std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_err(|_| state_error(ERROR_STATE_INVALID, "系统时钟无效"))?
        .as_millis() as u64)
}
fn result_key(kind: &str, request: &serde_json::Value) -> Result<String, String> {
    let id = request["message_id"].as_str().ok_or("缺少message_id")?;
    require_non_empty("message_id", id)?;
    if id.len() > 4096 {
        return Err("message_id过长".to_string());
    }
    Ok(format!("{kind}:{id}"))
}
fn committed_response(
    provider: &MlsProvider,
    kind: &str,
    input: *const c_char,
) -> Result<Option<String>, String> {
    let request: serde_json::Value = parse_request(input)?;
    let key = result_key(kind, &request)?;
    if let Some(saved) = provider.results.borrow().get(&key) {
        if saved.request != request {
            return Err("CHAT_MLS_REQUEST_CONFLICT:同一message_id请求发生变化".to_string());
        }
        let mut response = saved.result.clone();
        if kind == "process" && saved.acknowledged {
            response["status"] = json!("stale");
            response["committed"] = json!(true);
        }
        return serde_json::to_string(&response)
            .map(Some)
            .map_err(|_| state_error(ERROR_STATE_INVALID, "处理结果损坏"));
    }
    if provider
        .results
        .borrow()
        .values()
        .filter(|r| !r.acknowledged)
        .count()
        >= MAX_PENDING_RESULTS
    {
        return Err("CHAT_MLS_PENDING_FULL:必须先完成已有结果".to_string());
    }
    Ok(None)
}
fn commit_response(
    dir: &Path,
    provider: &MlsProvider,
    kind: &str,
    input: *const c_char,
    mut response: serde_json::Value,
) -> Result<String, String> {
    let request: serde_json::Value = parse_request(input)?;
    if kind == "process" && response["status"] != "applied" {
        return serde_json::to_string(&response)
            .map_err(|_| state_error(ERROR_STATE_INVALID, "结果序列化失败"));
    }
    let key = result_key(kind, &request)?;
    response["committed"] = json!(true);
    let now = now_millis()?;
    response["created_at_millis"] = json!(now);
    provider.results.borrow_mut().insert(
        key,
        CommittedResult {
            request,
            result: response.clone(),
            acknowledged: false,
            committed_at_millis: now,
            acknowledged_at_millis: None,
        },
    );
    save_provider(dir, provider)?;
    serde_json::to_string(&response).map_err(|_| state_error(ERROR_STATE_INVALID, "结果序列化失败"))
}

fn credential_with_public_key(
    user_id: &str,
    device_id: &str,
    public_key: Vec<u8>,
) -> CredentialWithKey {
    CredentialWithKey {
        credential: BasicCredential::new(format!("{user_id}:{device_id}").into_bytes()).into(),
        signature_key: public_key.into(),
    }
}

fn mls_group_config() -> MlsGroupCreateConfig {
    MlsGroupCreateConfig::builder()
        .ciphersuite(GMB_MLS_CIPHERSUITE)
        .use_ratchet_tree_extension(true)
        .build()
}

fn group_id_from_conversation(conversation_id: &str) -> Result<GroupId, String> {
    require_non_empty("conversation_id", conversation_id)?;
    Ok(GroupId::from_slice(conversation_id.as_bytes()))
}

fn decode_hex_field(field_name: &str, value: &str) -> Result<Vec<u8>, String> {
    let normalized = value.strip_prefix("0x").unwrap_or(value);
    if normalized.is_empty() {
        return Err(format!("{field_name} 不能为空"));
    }
    if !normalized.len().is_multiple_of(2) {
        return Err(format!("{field_name} hex 长度必须为偶数"));
    }
    hex::decode(normalized).map_err(|error| format!("{field_name} 不是合法 hex: {error}"))
}

fn storage_path(dir: &Path) -> PathBuf {
    dir.join("state.bin")
}
fn require_regular_file(path: &Path) -> Result<(), String> {
    let metadata = fs::symlink_metadata(path)
        .map_err(|_| state_error(ERROR_STORAGE_READ, "MLS文件缺失或不可读"))?;
    if !metadata.file_type().is_file() {
        return Err(state_error(ERROR_STORAGE_READ, "MLS文件类型非法"));
    }
    Ok(())
}
/// 独占文件锁覆盖读取、协议变更和提交整个事务。
fn lock_store(dir: &Path) -> Result<fs::File, String> {
    if !dir.is_absolute()
        || fs::canonicalize(dir).map_err(|_| state_error(ERROR_STORAGE_READ, "目录不可用"))? != dir
    {
        return Err(state_error(
            ERROR_STORAGE_READ,
            "目录必须是无符号链接绝对路径",
        ));
    }
    let path = dir.join("state.lock");
    if fs::symlink_metadata(&path).is_ok() {
        require_regular_file(&path)?;
    }
    let mut options = fs::OpenOptions::new();
    options.read(true).write(true).create(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
        #[cfg(any(target_os = "ios", target_os = "macos"))]
        options.custom_flags(0x100);
        #[cfg(any(target_os = "android", target_os = "linux"))]
        options.custom_flags(0x20000);
    }
    let file = options
        .open(path)
        .map_err(|_| state_error(ERROR_STORAGE_READ, "存储锁不可用"))?;
    file.lock()
        .map_err(|_| state_error(ERROR_STORAGE_READ, "存储锁失败"))?;
    Ok(file)
}
/// 先核验保护再写秘密；rename提交后同步父目录，不恢复旧ratchet快照。
fn atomic_write(path: &Path, bytes: &[u8]) -> Result<(), String> {
    use std::io::Write;
    let tmp = path.with_extension("writing");
    if fs::symlink_metadata(&tmp).is_ok() {
        require_regular_file(&tmp)?;
    }
    if fs::symlink_metadata(path).is_ok() {
        require_regular_file(path)?;
    }
    let mut options = fs::OpenOptions::new();
    options.write(true).create(true).truncate(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
        #[cfg(any(target_os = "ios", target_os = "macos"))]
        options.custom_flags(0x100);
        #[cfg(any(target_os = "android", target_os = "linux"))]
        options.custom_flags(0x20000);
    }
    let mut file = options
        .open(&tmp)
        .map_err(|_| state_error(ERROR_STORAGE_READ, "临时状态创建失败"))?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        file.set_permissions(fs::Permissions::from_mode(0o600))
            .map_err(|_| state_error(ERROR_STORAGE_READ, "权限设置失败"))?;
    }
    #[cfg(target_os = "ios")]
    {
        use std::os::fd::AsRawFd;
        unsafe extern "C" {
            fn fcntl(fd: i32, command: i32, ...) -> i32;
        }
        // Apple文件保护class C，写入前设置并回读。
        if unsafe { fcntl(file.as_raw_fd(), 64, 3) } != 0
            || unsafe { fcntl(file.as_raw_fd(), 63) } != 3
        {
            return Err(state_error(ERROR_STORAGE_READ, "文件保护不可用"));
        }
    }
    file.write_all(bytes)
        .map_err(|_| state_error(ERROR_STORAGE_READ, "状态写入失败"))?;
    file.sync_all()
        .map_err(|_| state_error(ERROR_STORAGE_READ, "状态同步失败"))?;
    fs::rename(&tmp, path).map_err(|_| state_error(ERROR_STORAGE_READ, "状态提交失败"))?;
    fs::File::open(path.parent().ok_or("状态缺少父目录")?)
        .and_then(|f| f.sync_all())
        .map_err(|_| state_error(ERROR_STORAGE_READ, "目录同步失败"))?;
    Ok(())
}
fn require_identity_component(value: &str) -> Result<(), String> {
    if value.trim().is_empty() || value.contains(':') || value.len() > 4096 {
        return Err("MLS身份标识无效".to_string());
    }
    Ok(())
}

fn require_non_empty(field_name: &str, value: &str) -> Result<(), String> {
    if value.trim().is_empty() {
        return Err(format!("OpenMLS 字段 {field_name} 不能为空"));
    }
    Ok(())
}

// ============================================================================
// 私密小群(MLS 群原生)FFI —— 单次加密 + 发送端扇出,服务端零存储不变。
// 密文/Welcome/Commit 都由本层生成,Dart 只按名册封 N 信封投递。
// 协议行为由本模块测试与 Dart FFI 边界共同固定。
// ============================================================================

/// 单群成员硬上限。发送端(Dart)与本层(MLS 实际成员数)双拦,任一超限即拒。
const MAX_GROUP_MEMBERS: usize = 1989;

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct GroupCreateRequest {
    state_store_dir: String,
    message_id: String,
    user_id: String,
    device_id: String,
    group_id: String,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct GroupAddMembersRequest {
    state_store_dir: String,
    message_id: String,
    user_id: String,
    device_id: String,
    group_id: String,
    key_packages_hex: Vec<String>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct GroupRemoveMembersRequest {
    state_store_dir: String,
    message_id: String,
    user_id: String,
    device_id: String,
    group_id: String,
    /// 按 用户身份 移除（移除该 用户身份 在群内的全部设备叶子）。
    member_user_ids: Vec<String>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct GroupCreateMessageRequest {
    state_store_dir: String,
    message_id: String,
    user_id: String,
    device_id: String,
    group_id: String,
    plaintext_hex: String,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct GroupProcessRequest {
    state_store_dir: String,
    message_id: String,
    user_id: String,
    device_id: String,
    group_id: String,
    wire_message_hex: String,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct GroupStateRequest {
    state_store_dir: String,
    user_id: String,
    device_id: String,
    group_id: String,
}

/// 创建 MLS 群(创建者为唯一成员,epoch 0)。
///
/// # Safety
/// 见 `tatachat_sdk_mls_create_key_package_json`。
#[no_mangle]
pub unsafe extern "C" fn tatachat_sdk_mls_group_create_json(
    request_json: *const c_char,
    error_out: *mut *mut c_char,
) -> *mut c_char {
    match group_create_json(request_json) {
        Ok(value) => crate::string_into_raw(value, error_out),
        Err(message) => {
            crate::set_error(error_out, &message);
            std::ptr::null_mut()
        }
    }
}

/// 批量加人:产 1 个 Commit(发给现有成员)+ 1 个 Welcome(发给全部新人)。
///
/// # Safety
/// 见 `tatachat_sdk_mls_create_key_package_json`。
#[no_mangle]
pub unsafe extern "C" fn tatachat_sdk_mls_group_add_members_json(
    request_json: *const c_char,
    error_out: *mut *mut c_char,
) -> *mut c_char {
    match group_add_members_json(request_json) {
        Ok(value) => crate::string_into_raw(value, error_out),
        Err(message) => {
            crate::set_error(error_out, &message);
            std::ptr::null_mut()
        }
    }
}

/// 删人:产 Commit(发给剩余成员 + 被删者)。
///
/// # Safety
/// 见 `tatachat_sdk_mls_create_key_package_json`。
#[no_mangle]
pub unsafe extern "C" fn tatachat_sdk_mls_group_remove_members_json(
    request_json: *const c_char,
    error_out: *mut *mut c_char,
) -> *mut c_char {
    match group_remove_members_json(request_json) {
        Ok(value) => crate::string_into_raw(value, error_out),
        Err(message) => {
            crate::set_error(error_out, &message);
            std::ptr::null_mut()
        }
    }
}

/// 群 application message:单次加密,Dart 侧按名册扇 N 信封。
///
/// # Safety
/// 见 `tatachat_sdk_mls_create_key_package_json`。
#[no_mangle]
pub unsafe extern "C" fn tatachat_sdk_mls_group_create_message_json(
    request_json: *const c_char,
    error_out: *mut *mut c_char,
) -> *mut c_char {
    match group_create_message_json(request_json) {
        Ok(value) => crate::string_into_raw(value, error_out),
        Err(message) => {
            crate::set_error(error_out, &message);
            std::ptr::null_mut()
        }
    }
}

/// 处理入站群消息(Welcome / Commit / Application)。收端唯一入口,按 epoch 判定
/// applied / out_of_order / stale,乱序缓冲由 Dart 依此状态负责。
///
/// # Safety
/// 见 `tatachat_sdk_mls_create_key_package_json`。
#[no_mangle]
pub unsafe extern "C" fn tatachat_sdk_mls_group_process_json(
    request_json: *const c_char,
    error_out: *mut *mut c_char,
) -> *mut c_char {
    match group_process_json(request_json) {
        Ok(value) => crate::string_into_raw(value, error_out),
        Err(message) => {
            crate::set_error(error_out, &message);
            std::ptr::null_mut()
        }
    }
}

/// 只读群状态:当前 epoch + 成员名册(MLS 真源,供 Dart 镜像对账与上限守)。
///
/// # Safety
/// 见 `tatachat_sdk_mls_create_key_package_json`。
#[no_mangle]
pub unsafe extern "C" fn tatachat_sdk_mls_group_state_json(
    request_json: *const c_char,
    error_out: *mut *mut c_char,
) -> *mut c_char {
    match group_state_json(request_json) {
        Ok(value) => crate::string_into_raw(value, error_out),
        Err(message) => {
            crate::set_error(error_out, &message);
            std::ptr::null_mut()
        }
    }
}

/// 从 BasicCredential 还原成员标识（"user_id:device_id"）。
fn identity_of(credential: &Credential) -> String {
    String::from_utf8_lossy(credential.serialized_content()).into_owned()
}

/// 从成员标识取 用户身份 段（"user_id:device_id" → "user_id"）。
fn user_id_of(credential: &Credential) -> String {
    let identity = identity_of(credential);
    match identity.split_once(':') {
        Some((user_id, _)) => user_id.to_string(),
        None => identity,
    }
}

fn group_create_json(request_json: *const c_char) -> Result<String, String> {
    let request: GroupCreateRequest = parse_request(request_json)?;
    // 消息标识在触碰持久状态之前校验，重放仍按完整原请求复核。
    require_non_empty("message_id", &request.message_id)?;
    require_non_empty("state_store_dir", &request.state_store_dir)?;
    require_non_empty("user_id", &request.user_id)?;
    require_non_empty("device_id", &request.device_id)?;
    require_non_empty("group_id", &request.group_id)?;

    let state_dir = Path::new(&request.state_store_dir);
    let _lock = lock_store(state_dir)?;
    let provider = load_provider(state_dir)?;
    let (credential, signer) = read_device_signer(&provider, &request.user_id, &request.device_id)?;
    if let Some(result) = committed_response(&provider, "create", request_json)? {
        return Ok(result);
    }
    let group_id = group_id_from_conversation(&request.group_id)?;
    if MlsGroup::load(provider.storage(), &group_id)
        .map_err(|error| format!("加载 MLS 群失败: {error:?}"))?
        .is_some()
    {
        return Err("MLS 群已存在，请勿重复创建".to_string());
    }
    let group = MlsGroup::new_with_group_id(
        &provider,
        &signer,
        &mls_group_config(),
        group_id,
        credential,
    )
    .map_err(|error| format!("创建 MLS 群失败: {error:?}"))?;
    let epoch = group.epoch().as_u64();

    let response = json!({
        "group_id": request.group_id,
        "epoch": epoch,
        "cipher_suite": format!("{:?}", GMB_MLS_CIPHERSUITE),
    });
    commit_response(state_dir, &provider, "create", request_json, response)
}

fn group_add_members_json(request_json: *const c_char) -> Result<String, String> {
    let request: GroupAddMembersRequest = parse_request(request_json)?;
    // 消息标识在触碰持久状态之前校验，重放仍按完整原请求复核。
    require_non_empty("message_id", &request.message_id)?;
    require_non_empty("state_store_dir", &request.state_store_dir)?;
    require_non_empty("user_id", &request.user_id)?;
    require_non_empty("device_id", &request.device_id)?;
    require_non_empty("group_id", &request.group_id)?;
    if request.key_packages_hex.is_empty() {
        return Err("group_add_members 至少需要一个 KeyPackage".to_string());
    }

    let state_dir = Path::new(&request.state_store_dir);
    let _lock = lock_store(state_dir)?;
    let provider = load_provider(state_dir)?;
    let (_credential, signer) =
        read_device_signer(&provider, &request.user_id, &request.device_id)?;
    if let Some(result) = committed_response(&provider, "add", request_json)? {
        return Ok(result);
    }
    let group_id = group_id_from_conversation(&request.group_id)?;
    let mut group = MlsGroup::load(provider.storage(), &group_id)
        .map_err(|error| format!("加载 MLS 群失败: {error:?}"))?
        .ok_or_else(|| "MLS 群不存在，无法加人".to_string())?;

    // 1989 硬拦(以 MLS 实际成员数为准,Dart 侧另有一道)。
    let current = group.members().count();
    let adding = request.key_packages_hex.len();
    if current + adding > MAX_GROUP_MEMBERS {
        return Err(format!(
            "群成员将达 {}，超过上限 {MAX_GROUP_MEMBERS}",
            current + adding
        ));
    }

    let prior_members: Vec<String> = group
        .members()
        .map(|m| identity_of(&m.credential))
        .collect();
    let mut key_packages = Vec::with_capacity(adding);
    for (index, kp_hex) in request.key_packages_hex.iter().enumerate() {
        let bytes = decode_hex_field(&format!("key_packages_hex[{index}]"), kp_hex)?;
        let key_package: KeyPackage = KeyPackageIn::tls_deserialize_exact(bytes)
            .map_err(|error| format!("反序列化 KeyPackage[{index}] 失败: {error}"))?
            .validate(provider.crypto(), ProtocolVersion::default())
            .map_err(|error| format!("验证 KeyPackage[{index}] 失败: {error:?}"))?;
        key_packages.push(key_package);
    }

    let welcome_members: Vec<String> = key_packages
        .iter()
        .map(|kp| identity_of(kp.leaf_node().credential()))
        .collect();
    let (commit, welcome, _group_info) = group
        .add_members(&provider, &signer, &key_packages)
        .map_err(|error| format!("MLS 加人失败: {error:?}"))?;
    group
        .merge_pending_commit(&provider)
        .map_err(|error| format!("合并 pending commit 失败: {error:?}"))?;

    let commit_wire_hex = hex::encode(
        commit
            .tls_serialize_detached()
            .map_err(|error| format!("序列化 Commit 失败: {error}"))?,
    );
    let welcome_wire_hex = hex::encode(
        welcome
            .tls_serialize_detached()
            .map_err(|error| format!("序列化 Welcome 失败: {error}"))?,
    );
    let epoch = group.epoch().as_u64();

    let response = json!({
        "group_id": request.group_id,
        "epoch": epoch,
        "commit_wire_hex": commit_wire_hex,
        "welcome_wire_hex": welcome_wire_hex,
        "welcome_member_identities": welcome_members,
        "prior_member_identities": prior_members,
    });
    commit_response(state_dir, &provider, "add", request_json, response)
}

fn group_remove_members_json(request_json: *const c_char) -> Result<String, String> {
    let request: GroupRemoveMembersRequest = parse_request(request_json)?;
    // 消息标识在触碰持久状态之前校验，重放仍按完整原请求复核。
    require_non_empty("message_id", &request.message_id)?;
    require_non_empty("state_store_dir", &request.state_store_dir)?;
    require_non_empty("user_id", &request.user_id)?;
    require_non_empty("device_id", &request.device_id)?;
    require_non_empty("group_id", &request.group_id)?;
    if request.member_user_ids.is_empty() {
        return Err("group_remove_members 至少需要一个成员 用户身份".to_string());
    }

    let state_dir = Path::new(&request.state_store_dir);
    let _lock = lock_store(state_dir)?;
    let provider = load_provider(state_dir)?;
    let (_credential, signer) =
        read_device_signer(&provider, &request.user_id, &request.device_id)?;
    if let Some(result) = committed_response(&provider, "remove", request_json)? {
        return Ok(result);
    }
    let group_id = group_id_from_conversation(&request.group_id)?;
    let mut group = MlsGroup::load(provider.storage(), &group_id)
        .map_err(|error| format!("加载 MLS 群失败: {error:?}"))?
        .ok_or_else(|| "MLS 群不存在，无法删人".to_string())?;

    // 按 用户身份 移除：该 用户身份 在群内的全部设备叶子都进移除集。
    let targets: HashSet<&str> = request
        .member_user_ids
        .iter()
        .map(|value| value.as_str())
        .collect();
    let prior_members: Vec<String> = group
        .members()
        .map(|m| identity_of(&m.credential))
        .collect();
    let mut indices = Vec::new();
    let mut removed_user_ids = HashSet::new();
    for member in group.members() {
        let user_id = user_id_of(&member.credential);
        if targets.contains(user_id.as_str()) {
            indices.push(member.index);
            removed_user_ids.insert(user_id);
        }
    }
    if indices.is_empty() {
        return Err("未在群名册中找到要移除的成员".to_string());
    }
    let removed_user_ids: Vec<String> = removed_user_ids.into_iter().collect();

    let (commit, _welcome, _group_info) = group
        .remove_members(&provider, &signer, &indices)
        .map_err(|error| format!("MLS 删人失败: {error:?}"))?;
    group
        .merge_pending_commit(&provider)
        .map_err(|error| format!("合并 pending commit 失败: {error:?}"))?;

    let commit_wire_hex = hex::encode(
        commit
            .tls_serialize_detached()
            .map_err(|error| format!("序列化 Commit 失败: {error}"))?,
    );
    let epoch = group.epoch().as_u64();

    let response = json!({
        "group_id": request.group_id,
        "epoch": epoch,
        "commit_wire_hex": commit_wire_hex,
        "removed_user_ids": removed_user_ids,
        "prior_member_identities": prior_members,
    });
    commit_response(state_dir, &provider, "remove", request_json, response)
}

fn group_create_message_json(request_json: *const c_char) -> Result<String, String> {
    let request: GroupCreateMessageRequest = parse_request(request_json)?;
    // 消息标识在触碰持久状态之前校验，重放仍按完整原请求复核。
    require_non_empty("message_id", &request.message_id)?;
    require_non_empty("state_store_dir", &request.state_store_dir)?;
    require_non_empty("user_id", &request.user_id)?;
    require_non_empty("device_id", &request.device_id)?;
    require_non_empty("group_id", &request.group_id)?;
    require_non_empty("plaintext_hex", &request.plaintext_hex)?;

    let state_dir = Path::new(&request.state_store_dir);
    let _lock = lock_store(state_dir)?;
    let provider = load_provider(state_dir)?;
    let (_credential, signer) =
        read_device_signer(&provider, &request.user_id, &request.device_id)?;
    if let Some(result) = committed_response(&provider, "send", request_json)? {
        return Ok(result);
    }
    let group_id = group_id_from_conversation(&request.group_id)?;
    let mut group = MlsGroup::load(provider.storage(), &group_id)
        .map_err(|error| format!("加载 MLS 群失败: {error:?}"))?
        .ok_or_else(|| "MLS 群不存在，无法发消息".to_string())?;

    let plaintext = decode_hex_field("plaintext_hex", &request.plaintext_hex)?;
    let message = group
        .create_message(&provider, &signer, &plaintext)
        .map_err(|error| format!("创建群 application message 失败: {error:?}"))?;
    let application_wire_hex = hex::encode(
        message
            .tls_serialize_detached()
            .map_err(|error| format!("序列化群 application message 失败: {error}"))?,
    );
    let epoch = group.epoch().as_u64();

    let response = json!({
        "group_id": request.group_id,
        "epoch": epoch,
        "application_wire_hex": application_wire_hex,
        "member_identities": group.members().map(|m| identity_of(&m.credential)).collect::<Vec<_>>(),
    });
    commit_response(state_dir, &provider, "send", request_json, response)
}

fn group_process_json(request_json: *const c_char) -> Result<String, String> {
    let request: GroupProcessRequest = parse_request(request_json)?;
    // 消息标识在触碰持久状态之前校验，重放仍按完整原请求复核。
    require_non_empty("message_id", &request.message_id)?;
    require_non_empty("state_store_dir", &request.state_store_dir)?;
    require_non_empty("user_id", &request.user_id)?;
    require_non_empty("device_id", &request.device_id)?;
    require_non_empty("group_id", &request.group_id)?;
    require_non_empty("wire_message_hex", &request.wire_message_hex)?;

    let state_dir = Path::new(&request.state_store_dir);
    let _lock = lock_store(state_dir)?;
    let provider = load_provider(state_dir)?;
    let _ = read_device_signer(&provider, &request.user_id, &request.device_id)?;
    if let Some(result) = committed_response(&provider, "process", request_json)? {
        return Ok(result);
    }
    let group_id = group_id_from_conversation(&request.group_id)?;
    let wire_bytes = decode_hex_field("wire_message_hex", &request.wire_message_hex)?;
    let message_in = MlsMessageIn::tls_deserialize_exact(wire_bytes)
        .map_err(|error| format!("反序列化 MLS wire message 失败: {error}"))?;

    let response = match message_in.extract() {
        MlsMessageBodyIn::Welcome(welcome) => {
            let group = StagedWelcome::new_from_welcome(
                &provider,
                mls_group_config().join_config(),
                welcome,
                None,
            )
            .map_err(|error| format!("处理群 Welcome 失败: {error:?}"))?
            .into_group(&provider)
            .map_err(|error| format!("从 Welcome 创建群失败: {error:?}"))?;
            if group.group_id() != &group_id {
                return Err("Welcome group_id 与 group_id 不一致".to_string());
            }
            let epoch = group.epoch().as_u64();
            let members: Vec<String> = group
                .members()
                .map(|m| identity_of(&m.credential))
                .collect();
            json!({
                "group_id": request.group_id,
                "message_kind": "welcome",
                "status": "applied",
                "message_epoch": epoch,
                "group_epoch": epoch,
                "self_removed": false,
                "plaintext_hex": serde_json::Value::Null,
                "member_identities": members,
            })
        }
        MlsMessageBodyIn::PublicMessage(message) => {
            process_group_protocol(&provider, &request.group_id, group_id, message.into())?
        }
        MlsMessageBodyIn::PrivateMessage(message) => {
            process_group_protocol(&provider, &request.group_id, group_id, message.into())?
        }
        _ => return Err("不支持的群 MLS wire message 类型".to_string()),
    };
    commit_response(state_dir, &provider, "process", request_json, response)
}

/// Commit/Application 的 epoch 有序处理。message_epoch>current→out_of_order(不处理,
/// Dart缓冲)；验密失败拒绝，精确已提交收据才允许判定重复。
fn process_group_protocol(
    provider: &MlsProvider,
    conversation_id: &str,
    group_id: GroupId,
    protocol_message: ProtocolMessage,
) -> Result<serde_json::Value, String> {
    let message_epoch = protocol_message.epoch().as_u64();
    let mut group = MlsGroup::load(provider.storage(), &group_id)
        .map_err(|error| format!("加载 MLS 群失败: {error:?}"))?
        .ok_or_else(|| "群会话不存在，需先处理 Welcome".to_string())?;
    let current = group.epoch().as_u64();

    if message_epoch > current {
        return Ok(json!({
            "group_id": conversation_id,
            "message_kind": "unknown",
            "status": "out_of_order",
            "message_epoch": message_epoch,
            "group_epoch": current,
            "self_removed": false,
            "plaintext_hex": serde_json::Value::Null,
            "member_identities": serde_json::Value::Null,
        }));
    }

    let processed = group
        .process_message(provider, protocol_message)
        .map_err(|_| "CHAT_MLS_MESSAGE_REJECTED:MLS验密失败，不能确认消息".to_string())?;

    match processed.into_content() {
        ProcessedMessageContent::ApplicationMessage(message) => {
            let plaintext = message.into_bytes();
            let epoch = group.epoch().as_u64();
            Ok(json!({
                "group_id": conversation_id,
                "message_kind": "application",
                "status": "applied",
                "message_epoch": message_epoch,
                "group_epoch": epoch,
                "self_removed": false,
                "plaintext_hex": hex::encode(plaintext),
                "member_identities": serde_json::Value::Null,
            }))
        }
        ProcessedMessageContent::StagedCommitMessage(staged) => {
            let self_removed = staged.self_removed();
            group
                .merge_staged_commit(provider, *staged)
                .map_err(|error| format!("合并群 Commit 失败: {error:?}"))?;
            let epoch = group.epoch().as_u64();
            let members: Vec<String> = if group.is_active() {
                group
                    .members()
                    .map(|m| identity_of(&m.credential))
                    .collect()
            } else {
                Vec::new()
            };
            Ok(json!({
                "group_id": conversation_id,
                "message_kind": "commit",
                "status": "applied",
                "message_epoch": message_epoch,
                "group_epoch": epoch,
                "self_removed": self_removed,
                "plaintext_hex": serde_json::Value::Null,
                "member_identities": members,
            }))
        }
        _ => Err("群暂不支持独立提案消息".to_string()),
    }
}

fn group_state_json(request_json: *const c_char) -> Result<String, String> {
    let request: GroupStateRequest = parse_request(request_json)?;
    require_non_empty("state_store_dir", &request.state_store_dir)?;
    require_non_empty("user_id", &request.user_id)?;
    require_non_empty("device_id", &request.device_id)?;
    require_non_empty("group_id", &request.group_id)?;

    let state_dir = Path::new(&request.state_store_dir);
    let _lock = lock_store(state_dir)?;
    let provider = load_provider(state_dir)?;
    let _ = read_device_signer(&provider, &request.user_id, &request.device_id)?;
    let group_id = group_id_from_conversation(&request.group_id)?;
    let group = MlsGroup::load(provider.storage(), &group_id)
        .map_err(|error| format!("加载 MLS 群失败: {error:?}"))?
        .ok_or_else(|| "MLS 群不存在".to_string())?;
    let epoch = group.epoch().as_u64();
    let members: Vec<String> = group
        .members()
        .map(|m| identity_of(&m.credential))
        .collect();

    let response = json!({
        "group_id": request.group_id,
        "epoch": epoch,
        "member_count": members.len(),
        "member_identities": members,
    });
    serde_json::to_string(&response).map_err(|error| error.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::{
        ffi::CString,
        sync::atomic::{AtomicUsize, Ordering},
    };
    static SERIAL: AtomicUsize = AtomicUsize::new(0);
    struct Fixture {
        dir: PathBuf,
        user: String,
        device: String,
    }
    impl Fixture {
        fn new(user: &str) -> Self {
            let dir = std::env::temp_dir().join(format!(
                "tatachat_mls_{}_{}",
                std::process::id(),
                SERIAL.fetch_add(1, Ordering::Relaxed)
            ));
            fs::create_dir(&dir).unwrap();
            let dir = fs::canonicalize(dir).unwrap();
            let identity = invoke(
                identity_json,
                json!({"state_store_dir":dir,"user_id":user,"action":"initialize"}),
            )
            .unwrap();
            Self {
                dir,
                user: user.into(),
                device: identity["device_id"].as_str().unwrap().into(),
            }
        }
        fn request(&self, id: &str) -> serde_json::Value {
            json!({"state_store_dir":self.dir,"user_id":self.user,"device_id":self.device,"message_id":id})
        }
        fn group(&self, id: &str, group: &str) -> serde_json::Value {
            let mut r = self.request(id);
            r["group_id"] = json!(group);
            r
        }
        fn acknowledge(&self, id: &str) {
            invoke(store_json, json!({"state_store_dir":self.dir,"user_id":self.user,"action":"acknowledge","message_id":id})).unwrap();
        }
    }
    impl Drop for Fixture {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.dir);
        }
    }
    fn invoke(
        f: fn(*const c_char) -> Result<String, String>,
        request: serde_json::Value,
    ) -> Result<serde_json::Value, String> {
        let c = CString::new(serde_json::to_string(&request).unwrap()).unwrap();
        serde_json::from_str(&f(c.as_ptr())?).map_err(|_| "合成响应解析失败".into())
    }
    fn pair() -> (Fixture, Fixture) {
        let a = Fixture::new("user-a");
        let b = Fixture::new("user-b");
        let mut kp = b.request("package");
        kp["last_resort"] = json!(true);
        let published = invoke(create_key_package_json, kp).unwrap();
        invoke(group_create_json, a.group("create", "group")).unwrap();
        let mut add = a.group("add", "group");
        add["key_packages_hex"] = json!([published["key_package_hex"]]);
        let added = invoke(group_add_members_json, add).unwrap();
        let mut welcome = b.group("welcome", "group");
        welcome["wire_message_hex"] = added["welcome_wire_hex"].clone();
        invoke(group_process_json, welcome).unwrap();
        (a, b)
    }
    #[test]
    fn identity_is_persistent_and_owner_scoped() {
        let a = Fixture::new("same-user");
        let other_device = Fixture::new("same-user");
        assert_ne!(a.device, other_device.device);
        let request = json!({"state_store_dir":a.dir,"user_id":a.user,"action":"read"});
        let first = invoke(identity_json, request.clone()).unwrap();
        assert_eq!(first, invoke(identity_json, request).unwrap());
        assert_eq!(first.as_object().unwrap().len(), 3);
        assert!(invoke(
            identity_json,
            json!({"state_store_dir":a.dir,"user_id":"other","action":"read"})
        )
        .unwrap_err()
        .starts_with("CHAT_MLS_STATE_OWNER_MISMATCH"));
        assert!(invoke(
            identity_json,
            json!({"state_store_dir":a.dir,"user_id":a.user,"action":"initialize"})
        )
        .is_err());
        fs::remove_file(storage_path(&a.dir)).unwrap();
        assert!(invoke(
            identity_json,
            json!({"state_store_dir":a.dir,"user_id":a.user,"action":"read"})
        )
        .is_err());
        assert!(!storage_path(&a.dir).exists());
    }
    #[test]
    fn requests_require_persistent_state_and_reject_unknown_fields() {
        assert!(invoke(
            create_key_package_json,
            json!({"user_id":"a","device_id":"d"})
        )
        .is_err());
        let a = Fixture::new("a");
        let mut req = a.request("package");
        req["unexpected"] = json!(true);
        assert!(invoke(create_key_package_json, req).is_err());
    }
    #[test]
    fn messages_survive_restart_before_host_commit() {
        let (a, b) = pair();
        let mut send = a.group("send-one", "group");
        send["plaintext_hex"] = json!(hex::encode("合成消息".as_bytes()));
        let first = invoke(group_create_message_json, send.clone()).unwrap();
        // 模拟上次返回前进程退出：重新load只取同一份已提交密文，不推进ratchet。
        assert_eq!(
            first,
            invoke(group_create_message_json, send.clone()).unwrap()
        );
        let mut receive = b.group("received-one", "group");
        receive["wire_message_hex"] = first["application_wire_hex"].clone();
        let clear = invoke(group_process_json, receive.clone()).unwrap();
        assert_eq!(clear["plaintext_hex"], send["plaintext_hex"]);
        assert_eq!(clear, invoke(group_process_json, receive.clone()).unwrap());
        b.acknowledge("received-one");
        let duplicate = invoke(group_process_json, receive.clone()).unwrap();
        assert_eq!(duplicate["status"], "stale");
        assert_eq!(duplicate["committed"], true);
        assert!(duplicate["plaintext_hex"].is_null());
        // 当前名册前进后，同一发送提交仍保留原密文及原接收设备集合。
        let mut remove = a.group("remove-later", "group");
        remove["member_user_ids"] = json!([b.user]);
        invoke(group_remove_members_json, remove).unwrap();
        assert_eq!(
            first,
            invoke(group_create_message_json, send.clone()).unwrap()
        );
        assert_eq!(first["member_identities"].as_array().unwrap().len(), 2);
        let mut state = a.group("unused-read-id", "group");
        state.as_object_mut().unwrap().remove("message_id");
        assert_eq!(invoke(group_state_json, state).unwrap()["member_count"], 1);
        send["plaintext_hex"] = json!(hex::encode(b"changed"));
        assert!(invoke(group_create_message_json, send)
            .unwrap_err()
            .starts_with("CHAT_MLS_REQUEST_CONFLICT"));
        receive["message_id"] = json!("different-message");
        assert!(invoke(group_process_json, receive)
            .unwrap_err()
            .starts_with("CHAT_MLS_MESSAGE_REJECTED"));
    }
    #[test]
    fn interrupted_temporary_write_does_not_replace_committed_identity() {
        let a = Fixture::new("user");
        atomic_write(&a.dir.join("unrelated.bin"), b"synthetic").unwrap();
        fs::write(
            storage_path(&a.dir).with_extension("writing"),
            b"incomplete",
        )
        .unwrap();
        let read = invoke(
            identity_json,
            json!({"state_store_dir":a.dir,"user_id":a.user,"action":"read"}),
        )
        .unwrap();
        assert_eq!(read["device_id"], a.device);
        fs::write(storage_path(&a.dir), b"broken").unwrap();
        assert!(invoke(
            identity_json,
            json!({"state_store_dir":a.dir,"user_id":a.user,"action":"read"})
        )
        .unwrap_err()
        .starts_with(ERROR_STATE_INVALID));
        assert_eq!(fs::read(storage_path(&a.dir)).unwrap(), b"broken");
    }
    #[test]
    fn independent_transactions_are_serialized_and_results_are_not_lost() {
        let (a, _b) = pair();
        let req = a.group("template", "group");
        let handles: Vec<_> = (0..8)
            .map(|i| {
                let mut request = req.clone();
                request["message_id"] = json!(format!("thread-{i}"));
                request["plaintext_hex"] = json!(hex::encode(format!("合成{i}")));
                std::thread::spawn(move || invoke(group_create_message_json, request).unwrap())
            })
            .collect();
        for handle in handles {
            assert_eq!(handle.join().unwrap()["committed"], true);
        }
        let pending = invoke(
            store_json,
            json!({"state_store_dir":a.dir,"user_id":a.user,"action":"pending_results"}),
        )
        .unwrap();
        assert_eq!(pending["results"].as_array().unwrap().len(), 10);
    }
    #[test]
    fn pending_ciphertext_and_receipts_use_same_owned_snapshot() {
        let a = Fixture::new("user");
        let req = |action| json!({"state_store_dir":a.dir,"user_id":a.user,"action":action});
        let mut queue = req("queue_pending");
        queue["pending_inbound"] = json!({"conversation_id":"group","wire_hex":"0102"});
        invoke(store_json, queue.clone()).unwrap();
        invoke(store_json, queue).unwrap();
        assert_eq!(
            invoke(store_json, req("read_pending")).unwrap()["pending_inbound"]
                .as_array()
                .unwrap()
                .len(),
            1
        );
        let mut write = req("write_receipt");
        write["handover_id"] = json!("binding");
        write["payload_json"] = json!("synthetic metadata");
        invoke(store_json, write).unwrap();
        let mut read = req("read_receipt");
        read["handover_id"] = json!("binding");
        assert_eq!(
            invoke(store_json, read).unwrap()["payload_json"],
            json!(["synthetic metadata"])
        );
    }
    #[test]
    fn openmls_smoke_remains_standard() {
        let result = invoke(two_party_smoke_json, json!({"plaintext":"合成消息"})).unwrap();
        assert_eq!(result["plaintext"], result["decrypted_plaintext"]);
    }
    #[cfg(unix)]
    #[test]
    fn state_file_is_private_and_links_are_rejected() {
        use std::os::unix::fs::{symlink, PermissionsExt};
        let a = Fixture::new("user");
        assert_eq!(
            fs::metadata(storage_path(&a.dir))
                .unwrap()
                .permissions()
                .mode()
                & 0o777,
            0o600
        );
        let target = a.dir.join("separate.bin");
        fs::rename(storage_path(&a.dir), &target).unwrap();
        symlink(&target, storage_path(&a.dir)).unwrap();
        assert!(invoke(
            identity_json,
            json!({"state_store_dir":a.dir,"user_id":a.user,"action":"read"})
        )
        .is_err());
    }
}
