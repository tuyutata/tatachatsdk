use std::{
    collections::HashSet,
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
use openmls_rust_crypto::{OpenMlsRustCrypto, RustCrypto};
use openmls_traits::{
    signatures::Signer, types::SignatureScheme, OpenMlsProvider as OpenMlsTraitsProvider,
};
use serde::{Deserialize, Serialize};
use serde_json::json;

const GMB_MLS_CIPHERSUITE: Ciphersuite = Ciphersuite::MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519;
/// MLS 本地状态信封的 AAD 域,把密文钉死在用途上,防止两个文件互换。
const STATE_AAD_STORAGE: &[u8] = b"tatachatsdk/mls|openmls_storage";
const STATE_AAD_DEVICE: &[u8] = b"tatachatsdk/mls|device_record";
const ERROR_STORAGE_READ: &str = "CHAT_MLS_STORAGE_READ_FAILED";
const ERROR_STORAGE_AUTH: &str = "CHAT_MLS_STORAGE_AUTH_FAILED";
const ERROR_DEVICE_READ: &str = "CHAT_MLS_DEVICE_READ_FAILED";
const ERROR_DEVICE_AUTH: &str = "CHAT_MLS_DEVICE_AUTH_FAILED";
const ERROR_STATE_INVALID: &str = "CHAT_MLS_STATE_INVALID";
const ERROR_SIGNER_MISSING: &str = "CHAT_MLS_SIGNER_MISSING";
/// GCM nonce 固定 12 字节;密文布局 = nonce || ciphertext || tag(16)。
const STATE_NONCE_LEN: usize = 12;

/// FFI 只依赖稳定阶段码分类，本地路径和底层错误只保留在技术信息中。
fn state_error(code: &str, message: impl std::fmt::Display) -> String {
    format!("{code}:{message}")
}

/// 解析 Dart 侧下传的 32 字节 MLS 状态密钥(小写 hex)。
///
/// 密钥由 用户身份 当前绑定钱包账户按 `LocalKeyPurpose.mls` 用途域派生，
/// Rust 侧只收密钥、不接触钱包种子。
fn parse_state_key(state_key_hex: &str) -> Result<[u8; 32], String> {
    let bytes = hex::decode(state_key_hex.trim_start_matches("0x"))
        .map_err(|error| format!("MLS 状态密钥不是合法 hex: {error}"))?;
    <[u8; 32]>::try_from(bytes.as_slice()).map_err(|_| "MLS 状态密钥必须为 32 字节".to_string())
}

/// AES-256-GCM 封装:随机 12 字节 nonce,输出 `nonce || ciphertext || tag`。
fn seal_state(key: &[u8; 32], plaintext: &[u8], aad: &[u8]) -> Result<Vec<u8>, String> {
    use aes_gcm::{
        aead::{Aead, KeyInit, OsRng, Payload},
        AeadCore, Aes256Gcm, Nonce,
    };
    let cipher = Aes256Gcm::new_from_slice(key)
        .map_err(|error| format!("构造 MLS 状态加密器失败: {error}"))?;
    let nonce = Aes256Gcm::generate_nonce(&mut OsRng);
    let ciphertext = cipher
        .encrypt(
            &nonce,
            Payload {
                msg: plaintext,
                aad,
            },
        )
        .map_err(|_| "MLS 状态加密失败".to_string())?;
    let mut out = Vec::with_capacity(STATE_NONCE_LEN + ciphertext.len());
    out.extend_from_slice(Nonce::<<Aes256Gcm as AeadCore>::NonceSize>::from_slice(
        nonce.as_slice(),
    ));
    out.extend_from_slice(&ciphertext);
    Ok(out)
}

/// AES-256-GCM 解封。密钥不符 / 密文被篡改一律报错,**绝不返回空状态**——
/// 静默降级会让 App 误以为"没有 MLS 状态"而重建身份,等于丢掉全部会话。
fn open_state(key: &[u8; 32], blob: &[u8], aad: &[u8]) -> Result<Vec<u8>, String> {
    use aes_gcm::{
        aead::{Aead, KeyInit, Payload},
        Aes256Gcm, Nonce,
    };
    if blob.len() <= STATE_NONCE_LEN {
        return Err("MLS 状态密文长度无效".to_string());
    }
    let cipher = Aes256Gcm::new_from_slice(key)
        .map_err(|error| format!("构造 MLS 状态解密器失败: {error}"))?;
    let nonce = Nonce::from_slice(&blob[..STATE_NONCE_LEN]);
    cipher
        .decrypt(
            nonce,
            Payload {
                msg: &blob[STATE_NONCE_LEN..],
                aad,
            },
        )
        .map_err(|_| "MLS 状态解密失败:密钥不匹配或密文被篡改".to_string())
}

#[derive(Deserialize)]
struct CreateKeyPackageRequest {
    user_id: String,
    device_id: String,
    state_store_dir: Option<String>,
    /// MLS 本地状态信封密钥(32 字节 hex)。无 state_store_dir 时可省。
    state_key_hex: Option<String>,
    /// 生成 RFC 9420 last-resort KeyPackage；服务端只保留每个 用户身份/设备一枚。
    #[serde(default)]
    last_resort: bool,
}

#[derive(Deserialize)]
struct TwoPartySmokeRequest {
    plaintext: String,
}

#[derive(Deserialize)]
struct RekeyStateRequest {
    state_store_dir: String,
    action: String,
    current_state_key_hex: Option<String>,
    new_state_key_hex: Option<String>,
}

#[derive(Serialize, Deserialize)]
struct DeviceRecord {
    user_id: String,
    device_id: String,
    signature_public_key_hex: String,
    signature_scheme: String,
}

struct MlsProvider {
    crypto: RustCrypto,
    storage: MemoryStorage,
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

/// 执行真实 OpenMLS 双人组 round-trip smoke。
///
/// # Safety
/// - `request_json` 必须是合法 UTF-8 C 字符串。
/// - 返回字符串必须由 `tatachat_sdk_free_string` 释放。
#[no_mangle]
pub unsafe extern "C" fn tatachat_sdk_mls_two_party_smoke_json(
    request_json: *const c_char,
    error_out: *mut *mut c_char,
) -> *mut c_char {
    match two_party_smoke_json(request_json) {
        Ok(value) => crate::string_into_raw(value, error_out),
        Err(message) => {
            crate::set_error(error_out, &message);
            std::ptr::null_mut()
        }
    }
}

/// 为 用户身份 钱包换绑暂存、提交或丢弃 MLS 状态的新账户密文。
///
/// `stage` 只在内存解开此前密文并写旁路新账户密文；`commit` 在 finalized 后替换正式
/// 文件；`discard` 删除旁路文件。任何动作都不会把 OpenMLS 状态明文写盘。
///
/// # Safety
/// - `request_json` 必须是合法 UTF-8 C 字符串。
/// - 返回字符串必须由 `tatachat_sdk_free_string` 释放。
#[no_mangle]
pub unsafe extern "C" fn tatachat_sdk_mls_rekey_state_json(
    request_json: *const c_char,
    error_out: *mut *mut c_char,
) -> *mut c_char {
    match rekey_state_json(request_json) {
        Ok(value) => crate::string_into_raw(value, error_out),
        Err(message) => {
            crate::set_error(error_out, &message);
            std::ptr::null_mut()
        }
    }
}

fn rekey_state_json(request_json: *const c_char) -> Result<String, String> {
    let request: RekeyStateRequest = parse_request(request_json)?;
    let state_dir = Path::new(&request.state_store_dir);
    match request.action.as_str() {
        "stage" => {
            let current_key = parse_state_key(
                request
                    .current_state_key_hex
                    .as_deref()
                    .ok_or_else(|| "stage 缺少 current_state_key_hex".to_string())?,
            )?;
            let new_key = parse_state_key(
                request
                    .new_state_key_hex
                    .as_deref()
                    .ok_or_else(|| "stage 缺少 new_state_key_hex".to_string())?,
            )?;
            stage_rekey_state_file(
                &storage_path(state_dir),
                &current_key,
                &new_key,
                STATE_AAD_STORAGE,
            )?;
            stage_rekey_state_file(
                &device_record_path(state_dir),
                &current_key,
                &new_key,
                STATE_AAD_DEVICE,
            )?;
        }
        "commit" => {
            commit_rekey_state_file(&storage_path(state_dir))?;
            commit_rekey_state_file(&device_record_path(state_dir))?;
        }
        "discard" => {
            discard_rekey_state_file(&storage_path(state_dir))?;
            discard_rekey_state_file(&device_record_path(state_dir))?;
        }
        _ => return Err("MLS 状态换绑 action 必须为 stage/commit/discard".to_string()),
    }
    serde_json::to_string(&serde_json::json!({"ok": true}))
        .map_err(|error| format!("序列化 MLS 状态换绑结果失败: {error}"))
}

fn create_key_package_json(request_json: *const c_char) -> Result<String, String> {
    let request: CreateKeyPackageRequest = parse_request(request_json)?;
    require_non_empty("user_id", &request.user_id)?;
    require_non_empty("device_id", &request.device_id)?;

    let (
        key_package_ref,
        key_package_hex,
        cipher_suite,
        not_before_millis,
        not_after_millis,
        last_resort,
    ) = if let Some(dir) = request.state_store_dir.as_deref() {
        let state_dir = Path::new(dir);
        let state_key_hex = request
            .state_key_hex
            .as_deref()
            .ok_or_else(|| "提供 state_store_dir 时必须同时提供 state_key_hex".to_string())?;
        let state_key = parse_state_key(state_key_hex)?;
        let provider = load_provider(state_dir, &state_key)?;
        let (credential, signer) = ensure_device_signer(
            &provider,
            state_dir,
            &request.user_id,
            &request.device_id,
            &state_key,
        )?;
        let bundle =
            generate_published_key_package(&provider, &signer, credential, request.last_resort)?;
        let publication = key_package_publication_fields(&provider, &bundle)?;
        save_provider(state_dir, &provider, &state_key)?;
        (
            publication.0,
            publication.1,
            format!("{:?}", GMB_MLS_CIPHERSUITE),
            publication.2,
            publication.3,
            publication.4,
        )
    } else {
        let provider = OpenMlsRustCrypto::default();
        let (credential, signer) = generate_credential(
            format!("{}:{}", request.user_id, request.device_id).into_bytes(),
            GMB_MLS_CIPHERSUITE.signature_algorithm(),
            &provider,
        )?;
        let bundle =
            generate_published_key_package(&provider, &signer, credential, request.last_resort)?;
        let publication = key_package_publication_fields(&provider, &bundle)?;
        (
            publication.0,
            publication.1,
            format!("{:?}", GMB_MLS_CIPHERSUITE),
            publication.2,
            publication.3,
            publication.4,
        )
    };
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
    serde_json::to_string(&response).map_err(|error| error.to_string())
}

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
    serde_json::from_str(request).map_err(|error| format!("解析 request_json 失败: {error}"))
}

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

/// OpenMLS storage 的可序列化形态。
///
/// 不走上游 `save_to_file` / `load_from_file`——那两个 API 硬绑 `&File`，只能把
/// **明文**直接写盘。这里改为自己序列化 `MemoryStorage.values`(公开字段)到内存
/// 缓冲，再整体 AEAD 加密落盘，全程无明文触盘。
#[derive(Serialize, Deserialize, Default)]
struct SerializableMlsStorage {
    values: std::collections::HashMap<String, String>,
}

fn load_provider(state_dir: &Path, state_key: &[u8; 32]) -> Result<MlsProvider, String> {
    fs::create_dir_all(state_dir).map_err(|error| {
        state_error(
            ERROR_STORAGE_READ,
            format!("创建 MLS 状态目录失败: {error}"),
        )
    })?;

    let storage = MemoryStorage::default();
    let storage_path = storage_path(state_dir);
    if storage_path.exists() {
        use base64::Engine;
        let blob = fs::read(&storage_path).map_err(|error| {
            state_error(
                ERROR_STORAGE_READ,
                format!("读取 OpenMLS storage 失败: {error}"),
            )
        })?;
        let clear = open_state(state_key, &blob, STATE_AAD_STORAGE)
            .map_err(|error| state_error(ERROR_STORAGE_AUTH, error))?;
        let parsed: SerializableMlsStorage = serde_json::from_slice(&clear).map_err(|error| {
            state_error(
                ERROR_STATE_INVALID,
                format!("解析 OpenMLS storage 失败: {error}"),
            )
        })?;
        let mut values = storage
            .values
            .write()
            .map_err(|_| "OpenMLS storage 写锁异常".to_string())?;
        for (key, value) in parsed.values {
            let key = base64::prelude::BASE64_STANDARD
                .decode(key)
                .map_err(|error| {
                    state_error(
                        ERROR_STATE_INVALID,
                        format!("OpenMLS storage 键解码失败: {error}"),
                    )
                })?;
            let value = base64::prelude::BASE64_STANDARD
                .decode(value)
                .map_err(|error| {
                    state_error(
                        ERROR_STATE_INVALID,
                        format!("OpenMLS storage 值解码失败: {error}"),
                    )
                })?;
            values.insert(key, value);
        }
    }
    Ok(MlsProvider {
        crypto: RustCrypto::default(),
        storage,
    })
}

fn save_provider(
    state_dir: &Path,
    provider: &MlsProvider,
    state_key: &[u8; 32],
) -> Result<(), String> {
    use base64::Engine;
    fs::create_dir_all(state_dir).map_err(|error| format!("创建 MLS 状态目录失败: {error}"))?;

    let mut serializable = SerializableMlsStorage::default();
    {
        let values = provider
            .storage()
            .values
            .read()
            .map_err(|_| "OpenMLS storage 读锁异常".to_string())?;
        for (key, value) in &*values {
            serializable.values.insert(
                base64::prelude::BASE64_STANDARD.encode(key),
                base64::prelude::BASE64_STANDARD.encode(value),
            );
        }
    }
    let clear = serde_json::to_vec(&serializable)
        .map_err(|error| format!("序列化 OpenMLS storage 失败: {error}"))?;
    let sealed = seal_state(state_key, &clear, STATE_AAD_STORAGE)?;
    atomic_write(&storage_path(state_dir), &sealed)?;
    Ok(())
}

fn ensure_device_signer(
    provider: &MlsProvider,
    state_dir: &Path,
    user_id: &str,
    device_id: &str,
    state_key: &[u8; 32],
) -> Result<(CredentialWithKey, SignatureKeyPair), String> {
    let record_path = device_record_path(state_dir);
    let signature_algorithm = GMB_MLS_CIPHERSUITE.signature_algorithm();
    if record_path.exists() {
        let blob = fs::read(&record_path).map_err(|error| {
            state_error(ERROR_DEVICE_READ, format!("读取 MLS 设备记录失败: {error}"))
        })?;
        let clear = open_state(state_key, &blob, STATE_AAD_DEVICE)
            .map_err(|error| state_error(ERROR_DEVICE_AUTH, error))?;
        let record: DeviceRecord = serde_json::from_slice(&clear).map_err(|error| {
            state_error(
                ERROR_STATE_INVALID,
                format!("解析 MLS 设备记录失败: {error}"),
            )
        })?;
        if record.user_id != user_id || record.device_id != device_id {
            return Err(
                "CHAT_MLS_STATE_OWNER_MISMATCH:MLS 状态目录已绑定到其他 用户身份 或设备"
                    .to_string(),
            );
        }
        let public_key =
            decode_hex_field("signature_public_key_hex", &record.signature_public_key_hex)
                .map_err(|error| state_error(ERROR_STATE_INVALID, error))?;
        let signer = SignatureKeyPair::read(provider.storage(), &public_key, signature_algorithm)
            .ok_or_else(|| {
            state_error(
                ERROR_SIGNER_MISSING,
                "MLS 设备签名密钥不在 OpenMLS storage 中",
            )
        })?;
        let credential = credential_with_public_key(user_id, device_id, public_key);
        return Ok((credential, signer));
    }

    let (credential, signer) = generate_credential(
        format!("{user_id}:{device_id}").into_bytes(),
        signature_algorithm,
        provider,
    )?;
    let record = DeviceRecord {
        user_id: user_id.to_string(),
        device_id: device_id.to_string(),
        signature_public_key_hex: hex::encode(signer.to_public_vec()),
        signature_scheme: format!("{:?}", signature_algorithm),
    };
    let clear = serde_json::to_vec(&record).map_err(|error| error.to_string())?;
    let sealed = seal_state(state_key, &clear, STATE_AAD_DEVICE)?;
    atomic_write(&record_path, &sealed)?;
    Ok((credential, signer))
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

fn storage_path(state_dir: &Path) -> PathBuf {
    state_dir.join("openmls_storage.bin")
}

fn device_record_path(state_dir: &Path) -> PathBuf {
    state_dir.join("device.bin")
}

fn rekey_staged_path(path: &Path) -> PathBuf {
    path.with_extension("account_rekey")
}

fn stage_rekey_state_file(
    path: &Path,
    current_key: &[u8; 32],
    new_key: &[u8; 32],
    aad: &[u8],
) -> Result<(), String> {
    if !path.exists() {
        return Ok(());
    }
    let current_blob = fs::read(path).map_err(|error| format!("读取 MLS 当前状态失败: {error}"))?;
    let mut clear = open_state(current_key, &current_blob, aad)?;
    let new_blob = seal_state(new_key, &clear, aad)?;
    clear.fill(0);
    // 写盘前再用新钥认证一次，确保“新密钥已上岗”不是只写未验。
    let mut verified = open_state(new_key, &new_blob, aad)?;
    verified.fill(0);
    atomic_write(&rekey_staged_path(path), &new_blob)
}

fn commit_rekey_state_file(path: &Path) -> Result<(), String> {
    let staged = rekey_staged_path(path);
    if !staged.exists() {
        return Ok(());
    }
    fs::rename(&staged, path).map_err(|error| format!("提交 MLS 新账户状态密文失败: {error}"))
}

fn discard_rekey_state_file(path: &Path) -> Result<(), String> {
    let staged = rekey_staged_path(path);
    if staged.exists() {
        fs::remove_file(staged).map_err(|error| format!("删除 MLS 换绑暂存失败: {error}"))?;
    }
    Ok(())
}

/// 原子写入:先写同目录临时文件、fsync,再 rename 覆盖目标。
///
/// MLS 状态一旦被写坏(例如写到一半崩溃导致截断),该设备的**全部群与会话都不可读**。
/// rename 在同一文件系统上是原子的,保证要么是完整旧内容、要么是完整新内容。
fn atomic_write(path: &Path, bytes: &[u8]) -> Result<(), String> {
    use std::io::Write;
    let tmp = path.with_extension("tmp");
    {
        let mut file = fs::File::create(&tmp)
            .map_err(|error| format!("创建 MLS 状态临时文件失败: {error}"))?;
        file.write_all(bytes)
            .map_err(|error| format!("写入 MLS 状态临时文件失败: {error}"))?;
        file.sync_all()
            .map_err(|error| format!("同步 MLS 状态临时文件失败: {error}"))?;
    }
    fs::rename(&tmp, path).map_err(|error| {
        let _ = fs::remove_file(&tmp);
        format!("替换 MLS 状态文件失败: {error}")
    })
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
struct GroupCreateRequest {
    state_store_dir: String,
    /// MLS 本地状态信封密钥(32 字节 hex),由 Dart 侧 LocalKeyPurpose.mls 子钥下传。
    state_key_hex: String,
    user_id: String,
    device_id: String,
    group_id: String,
}

#[derive(Deserialize)]
struct GroupAddMembersRequest {
    state_store_dir: String,
    /// MLS 本地状态信封密钥(32 字节 hex),由 Dart 侧 LocalKeyPurpose.mls 子钥下传。
    state_key_hex: String,
    user_id: String,
    device_id: String,
    group_id: String,
    key_packages_hex: Vec<String>,
}

#[derive(Deserialize)]
struct GroupRemoveMembersRequest {
    state_store_dir: String,
    /// MLS 本地状态信封密钥(32 字节 hex),由 Dart 侧 LocalKeyPurpose.mls 子钥下传。
    state_key_hex: String,
    user_id: String,
    device_id: String,
    group_id: String,
    /// 按 用户身份 移除（移除该 用户身份 在群内的全部设备叶子）。
    member_user_ids: Vec<String>,
}

#[derive(Deserialize)]
struct GroupCreateMessageRequest {
    state_store_dir: String,
    /// MLS 本地状态信封密钥(32 字节 hex),由 Dart 侧 LocalKeyPurpose.mls 子钥下传。
    state_key_hex: String,
    user_id: String,
    device_id: String,
    group_id: String,
    plaintext_hex: String,
}

#[derive(Deserialize)]
struct GroupProcessRequest {
    state_store_dir: String,
    /// MLS 本地状态信封密钥(32 字节 hex),由 Dart 侧 LocalKeyPurpose.mls 子钥下传。
    state_key_hex: String,
    user_id: String,
    device_id: String,
    group_id: String,
    wire_message_hex: String,
}

#[derive(Deserialize)]
struct GroupStateRequest {
    state_store_dir: String,
    /// MLS 本地状态信封密钥(32 字节 hex),由 Dart 侧 LocalKeyPurpose.mls 子钥下传。
    state_key_hex: String,
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
    require_non_empty("state_store_dir", &request.state_store_dir)?;
    require_non_empty("user_id", &request.user_id)?;
    require_non_empty("device_id", &request.device_id)?;
    require_non_empty("group_id", &request.group_id)?;

    let state_dir = Path::new(&request.state_store_dir);
    let state_key = parse_state_key(&request.state_key_hex)?;
    let provider = load_provider(state_dir, &state_key)?;
    let (credential, signer) = ensure_device_signer(
        &provider,
        state_dir,
        &request.user_id,
        &request.device_id,
        &state_key,
    )?;
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
    save_provider(state_dir, &provider, &state_key)?;

    let response = json!({
        "group_id": request.group_id,
        "epoch": epoch,
        "cipher_suite": format!("{:?}", GMB_MLS_CIPHERSUITE),
    });
    serde_json::to_string(&response).map_err(|error| error.to_string())
}

fn group_add_members_json(request_json: *const c_char) -> Result<String, String> {
    let request: GroupAddMembersRequest = parse_request(request_json)?;
    require_non_empty("state_store_dir", &request.state_store_dir)?;
    require_non_empty("user_id", &request.user_id)?;
    require_non_empty("device_id", &request.device_id)?;
    require_non_empty("group_id", &request.group_id)?;
    if request.key_packages_hex.is_empty() {
        return Err("group_add_members 至少需要一个 KeyPackage".to_string());
    }

    let state_dir = Path::new(&request.state_store_dir);
    let state_key = parse_state_key(&request.state_key_hex)?;
    let provider = load_provider(state_dir, &state_key)?;
    let (_credential, signer) = ensure_device_signer(
        &provider,
        state_dir,
        &request.user_id,
        &request.device_id,
        &state_key,
    )?;
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

    let mut key_packages = Vec::with_capacity(adding);
    for (index, kp_hex) in request.key_packages_hex.iter().enumerate() {
        let bytes = decode_hex_field(&format!("key_packages_hex[{index}]"), kp_hex)?;
        let key_package: KeyPackage = KeyPackageIn::tls_deserialize_exact(bytes)
            .map_err(|error| format!("反序列化 KeyPackage[{index}] 失败: {error}"))?
            .validate(provider.crypto(), ProtocolVersion::default())
            .map_err(|error| format!("验证 KeyPackage[{index}] 失败: {error:?}"))?;
        key_packages.push(key_package);
    }

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
    save_provider(state_dir, &provider, &state_key)?;

    let response = json!({
        "group_id": request.group_id,
        "epoch": epoch,
        "commit_wire_hex": commit_wire_hex,
        "welcome_wire_hex": welcome_wire_hex,
    });
    serde_json::to_string(&response).map_err(|error| error.to_string())
}

fn group_remove_members_json(request_json: *const c_char) -> Result<String, String> {
    let request: GroupRemoveMembersRequest = parse_request(request_json)?;
    require_non_empty("state_store_dir", &request.state_store_dir)?;
    require_non_empty("user_id", &request.user_id)?;
    require_non_empty("device_id", &request.device_id)?;
    require_non_empty("group_id", &request.group_id)?;
    if request.member_user_ids.is_empty() {
        return Err("group_remove_members 至少需要一个成员 用户身份".to_string());
    }

    let state_dir = Path::new(&request.state_store_dir);
    let state_key = parse_state_key(&request.state_key_hex)?;
    let provider = load_provider(state_dir, &state_key)?;
    let (_credential, signer) = ensure_device_signer(
        &provider,
        state_dir,
        &request.user_id,
        &request.device_id,
        &state_key,
    )?;
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
    save_provider(state_dir, &provider, &state_key)?;

    let response = json!({
        "group_id": request.group_id,
        "epoch": epoch,
        "commit_wire_hex": commit_wire_hex,
        "removed_user_ids": removed_user_ids,
    });
    serde_json::to_string(&response).map_err(|error| error.to_string())
}

fn group_create_message_json(request_json: *const c_char) -> Result<String, String> {
    let request: GroupCreateMessageRequest = parse_request(request_json)?;
    require_non_empty("state_store_dir", &request.state_store_dir)?;
    require_non_empty("user_id", &request.user_id)?;
    require_non_empty("device_id", &request.device_id)?;
    require_non_empty("group_id", &request.group_id)?;
    require_non_empty("plaintext_hex", &request.plaintext_hex)?;

    let state_dir = Path::new(&request.state_store_dir);
    let state_key = parse_state_key(&request.state_key_hex)?;
    let provider = load_provider(state_dir, &state_key)?;
    let (_credential, signer) = ensure_device_signer(
        &provider,
        state_dir,
        &request.user_id,
        &request.device_id,
        &state_key,
    )?;
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
    save_provider(state_dir, &provider, &state_key)?;

    let response = json!({
        "group_id": request.group_id,
        "epoch": epoch,
        "application_wire_hex": application_wire_hex,
    });
    serde_json::to_string(&response).map_err(|error| error.to_string())
}

fn group_process_json(request_json: *const c_char) -> Result<String, String> {
    let request: GroupProcessRequest = parse_request(request_json)?;
    require_non_empty("state_store_dir", &request.state_store_dir)?;
    require_non_empty("user_id", &request.user_id)?;
    require_non_empty("device_id", &request.device_id)?;
    require_non_empty("group_id", &request.group_id)?;
    require_non_empty("wire_message_hex", &request.wire_message_hex)?;

    let state_dir = Path::new(&request.state_store_dir);
    let state_key = parse_state_key(&request.state_key_hex)?;
    let provider = load_provider(state_dir, &state_key)?;
    let _ = ensure_device_signer(
        &provider,
        state_dir,
        &request.user_id,
        &request.device_id,
        &state_key,
    )?;
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
            save_provider(state_dir, &provider, &state_key)?;
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
        MlsMessageBodyIn::PublicMessage(message) => process_group_protocol(
            state_dir,
            &provider,
            &state_key,
            &request.group_id,
            group_id,
            message.into(),
        )?,
        MlsMessageBodyIn::PrivateMessage(message) => process_group_protocol(
            state_dir,
            &provider,
            &state_key,
            &request.group_id,
            group_id,
            message.into(),
        )?,
        _ => return Err("不支持的群 MLS wire message 类型".to_string()),
    };
    serde_json::to_string(&response).map_err(|error| error.to_string())
}

/// Commit/Application 的 epoch 有序处理。message_epoch>current→out_of_order(不处理,
/// Dart 缓冲);<current 或解密失败→stale;==→应用并回吐名册/自我移除标志。
fn process_group_protocol(
    state_dir: &Path,
    provider: &MlsProvider,
    state_key: &[u8; 32],
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

    let processed = match group.process_message(provider, protocol_message) {
        Ok(processed) => processed,
        Err(error) => {
            return Ok(json!({
                "group_id": conversation_id,
                "message_kind": "unknown",
                "status": "stale",
                "message_epoch": message_epoch,
                "group_epoch": current,
                "self_removed": false,
                "plaintext_hex": serde_json::Value::Null,
                "member_identities": serde_json::Value::Null,
                "detail": format!("{error:?}"),
            }));
        }
    };

    match processed.into_content() {
        ProcessedMessageContent::ApplicationMessage(message) => {
            let plaintext = message.into_bytes();
            let epoch = group.epoch().as_u64();
            save_provider(state_dir, provider, state_key)?;
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
            save_provider(state_dir, provider, state_key)?;
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
    let state_key = parse_state_key(&request.state_key_hex)?;
    let provider = load_provider(state_dir, &state_key)?;
    let _ = ensure_device_signer(
        &provider,
        state_dir,
        &request.user_id,
        &request.device_id,
        &state_key,
    )?;
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
    use super::{
        atomic_write, create_key_package_json, group_add_members_json, group_create_json,
        group_create_message_json, group_process_json, group_remove_members_json, group_state_json,
        open_state, parse_state_key, seal_state, two_party_smoke_json, ERROR_DEVICE_AUTH,
        ERROR_STATE_INVALID, ERROR_STORAGE_AUTH, STATE_AAD_DEVICE, STATE_AAD_STORAGE,
    };
    use std::ffi::CString;
    use std::fs;

    /// MLS 状态信封测试密钥(64 hex = 32 字节)。
    const TEST_STATE_KEY_HEX: &str =
        "0101010101010101010101010101010101010101010101010101010101010101";

    #[test]
    fn creates_real_openmls_key_package() {
        let request = CString::new(r#"{"user_id":"用户身份-ALICE","device_id":"alice-phone"}"#)
            .expect("request should be valid");
        let response =
            create_key_package_json(request.as_ptr()).expect("key package should be created");
        let json: serde_json::Value =
            serde_json::from_str(&response).expect("response should be json");
        assert_eq!(json["user_id"], "用户身份-ALICE");
        assert!(json["key_package_hex"].as_str().unwrap().len() > 100);
        let not_before = json["not_before_millis"].as_u64().unwrap();
        let not_after = json["not_after_millis"].as_u64().unwrap();
        // OpenMLS 0.8.1 默认 84 天，并额外向过去留 1 小时时钟偏差窗口。
        assert_eq!(not_after - not_before, (84 * 24 + 1) * 60 * 60 * 1000);
        assert_eq!(json["last_resort"], false);
        let key_package_ref = json["key_package_ref"]
            .as_str()
            .expect("响应必须含 RFC 9420 KeyPackageRef");
        assert!(!key_package_ref.is_empty());
        assert!(key_package_ref
            .chars()
            .all(|c| c.is_ascii_digit() || ('a'..='f').contains(&c)));
    }

    #[test]
    fn creates_openmls_last_resort_key_package() {
        let request = CString::new(
            r#"{"user_id":"用户身份-ALICE","device_id":"alice-phone","last_resort":true}"#,
        )
        .expect("request should be valid");
        let response = create_key_package_json(request.as_ptr())
            .expect("last-resort key package should be created");
        let json: serde_json::Value =
            serde_json::from_str(&response).expect("response should be json");
        assert_eq!(json["last_resort"], true);
        assert!(
            json["not_after_millis"].as_u64().unwrap()
                > json["not_before_millis"].as_u64().unwrap()
        );
    }

    #[test]
    fn openmls_two_party_smoke_round_trips_plaintext() {
        let request =
            CString::new(r#"{"plaintext":"hello openmls"}"#).expect("request should be valid");
        let response = two_party_smoke_json(request.as_ptr()).expect("smoke should pass");
        let json: serde_json::Value =
            serde_json::from_str(&response).expect("response should be json");
        assert_eq!(json["plaintext"], "hello openmls");
        assert_eq!(json["decrypted_plaintext"], "hello openmls");
        assert!(json["alice_wire_message_hex"].as_str().unwrap().len() > 100);
    }

    #[test]
    fn group_three_party_round_trip() {
        use serde_json::json;
        use std::fs;
        use std::os::raw::c_char;
        use std::path::Path;

        let base = std::env::temp_dir().join(format!("chat_group_rt_{}", std::process::id()));
        let _ = fs::remove_dir_all(&base);
        let dir_a = base.join("a");
        let dir_b = base.join("b");
        let dir_c = base.join("c");
        for d in [&dir_a, &dir_b, &dir_c] {
            fs::create_dir_all(d).expect("临时目录应可创建");
        }
        let group_id = "grp:用户身份-A:testnonce";
        let path = |p: &Path| p.to_str().unwrap().to_string();

        let invoke = |f: fn(*const c_char) -> Result<String, String>, req: serde_json::Value| {
            let c = CString::new(serde_json::to_string(&req).unwrap()).unwrap();
            let out = f(c.as_ptr()).expect("FFI 调用应成功");
            serde_json::from_str::<serde_json::Value>(&out).expect("响应应为 JSON")
        };

        // A 建群(创建者=唯一成员,epoch 0)。
        let created = invoke(
            group_create_json,
            json!({"state_key_hex": TEST_STATE_KEY_HEX, "state_store_dir": path(&dir_a), "user_id": "用户身份-A", "device_id": "devA", "group_id": group_id}),
        );
        assert_eq!(created["epoch"].as_u64(), Some(0));

        // B / C 生成 KeyPackage。
        let b_kp = invoke(
            create_key_package_json,
            json!({"user_id": "用户身份-B", "device_id": "devB", "state_store_dir": path(&dir_b), "state_key_hex": TEST_STATE_KEY_HEX}),
        )["key_package_hex"]
            .as_str()
            .unwrap()
            .to_string();
        let c_kp = invoke(
            create_key_package_json,
            json!({"user_id": "用户身份-C", "device_id": "devC", "state_store_dir": path(&dir_c), "state_key_hex": TEST_STATE_KEY_HEX}),
        )["key_package_hex"]
            .as_str()
            .unwrap()
            .to_string();

        // A 批量加 B、C(1 Commit + 1 Welcome)。
        let added = invoke(
            group_add_members_json,
            json!({"state_key_hex": TEST_STATE_KEY_HEX, "state_store_dir": path(&dir_a), "user_id": "用户身份-A", "device_id": "devA", "group_id": group_id, "key_packages_hex": [b_kp, c_kp]}),
        );
        let welcome_hex = added["welcome_wire_hex"].as_str().unwrap().to_string();
        assert_eq!(added["epoch"].as_u64(), Some(1));

        // B / C 处理 Welcome 入群,名册应为 3 人。
        for (dir, owner, dev) in [
            (&dir_b, "用户身份-B", "devB"),
            (&dir_c, "用户身份-C", "devC"),
        ] {
            let joined = invoke(
                group_process_json,
                json!({"state_key_hex": TEST_STATE_KEY_HEX, "state_store_dir": path(dir.as_path()), "user_id": owner, "device_id": dev, "group_id": group_id, "wire_message_hex": welcome_hex}),
            );
            assert_eq!(joined["message_kind"].as_str(), Some("welcome"));
            assert_eq!(joined["member_identities"].as_array().unwrap().len(), 3);
        }

        // A 发文本,B/C 端到端解密。
        let plaintext_hex = hex::encode("你好，群聊".as_bytes());
        let msg = invoke(
            group_create_message_json,
            json!({"state_key_hex": TEST_STATE_KEY_HEX, "state_store_dir": path(&dir_a), "user_id": "用户身份-A", "device_id": "devA", "group_id": group_id, "plaintext_hex": plaintext_hex}),
        );
        let app_hex = msg["application_wire_hex"].as_str().unwrap().to_string();
        for (dir, owner, dev) in [
            (&dir_b, "用户身份-B", "devB"),
            (&dir_c, "用户身份-C", "devC"),
        ] {
            let got = invoke(
                group_process_json,
                json!({"state_key_hex": TEST_STATE_KEY_HEX, "state_store_dir": path(dir.as_path()), "user_id": owner, "device_id": dev, "group_id": group_id, "wire_message_hex": app_hex}),
            );
            assert_eq!(got["message_kind"].as_str(), Some("application"));
            assert_eq!(got["status"].as_str(), Some("applied"));
            assert_eq!(got["plaintext_hex"].as_str(), Some(plaintext_hex.as_str()));
        }

        // A 移除 C。
        let removed = invoke(
            group_remove_members_json,
            json!({"state_key_hex": TEST_STATE_KEY_HEX, "state_store_dir": path(&dir_a), "user_id": "用户身份-A", "device_id": "devA", "group_id": group_id, "member_user_ids": ["用户身份-C"]}),
        );
        let remove_commit_hex = removed["commit_wire_hex"].as_str().unwrap().to_string();
        assert_eq!(removed["epoch"].as_u64(), Some(2));

        // B 应用 Commit → 名册剩 A、B,未自我移除。
        let b_after = invoke(
            group_process_json,
            json!({"state_key_hex": TEST_STATE_KEY_HEX, "state_store_dir": path(&dir_b), "user_id": "用户身份-B", "device_id": "devB", "group_id": group_id, "wire_message_hex": remove_commit_hex}),
        );
        assert_eq!(b_after["message_kind"].as_str(), Some("commit"));
        assert_eq!(b_after["self_removed"].as_bool(), Some(false));
        assert_eq!(b_after["member_identities"].as_array().unwrap().len(), 2);

        // C 应用 Commit → 自身被移除(后向保密)。
        let c_after = invoke(
            group_process_json,
            json!({"state_key_hex": TEST_STATE_KEY_HEX, "state_store_dir": path(&dir_c), "user_id": "用户身份-C", "device_id": "devC", "group_id": group_id, "wire_message_hex": remove_commit_hex}),
        );
        assert_eq!(c_after["self_removed"].as_bool(), Some(true));

        // group_state 名册对账 = A、B。
        let state = invoke(
            group_state_json,
            json!({"state_key_hex": TEST_STATE_KEY_HEX, "state_store_dir": path(&dir_a), "user_id": "用户身份-A", "device_id": "devA", "group_id": group_id}),
        );
        assert_eq!(state["member_count"].as_u64(), Some(2));

        let _ = fs::remove_dir_all(&base);
    }

    #[test]
    fn state_envelope_round_trip() {
        let key = [7u8; 32];
        let clear = b"MLS \xe7\xa7\x81\xe9\x92\xa5";
        let sealed = seal_state(&key, clear, STATE_AAD_STORAGE).expect("seal");
        // 密文里不得出现明文
        assert!(!sealed.windows(clear.len()).any(|w| w == clear));
        let opened = open_state(&key, &sealed, STATE_AAD_STORAGE).expect("open");
        assert_eq!(opened, clear);
    }

    #[test]
    fn state_envelope_rejects_wrong_key() {
        let sealed = seal_state(&[1u8; 32], b"x", STATE_AAD_STORAGE).expect("seal");
        assert!(open_state(&[2u8; 32], &sealed, STATE_AAD_STORAGE).is_err());
    }

    #[test]
    fn state_envelope_rejects_wrong_aad() {
        let key = [3u8; 32];
        let sealed = seal_state(&key, b"x", STATE_AAD_STORAGE).expect("seal");
        // storage 与 device 两个域不可互换,防止两个文件被对调
        assert!(open_state(&key, &sealed, STATE_AAD_DEVICE).is_err());
    }

    #[test]
    fn state_envelope_rejects_tampered_ciphertext() {
        let key = [4u8; 32];
        let mut sealed = seal_state(&key, b"hello", STATE_AAD_STORAGE).expect("seal");
        let last = sealed.len() - 1;
        sealed[last] ^= 0xFF;
        assert!(open_state(&key, &sealed, STATE_AAD_STORAGE).is_err());
    }

    #[test]
    fn state_envelope_nonce_is_random() {
        let key = [5u8; 32];
        let a = seal_state(&key, b"same", STATE_AAD_STORAGE).expect("seal");
        let b = seal_state(&key, b"same", STATE_AAD_STORAGE).expect("seal");
        assert_ne!(a, b, "同明文同密钥两次密文必须不同");
    }

    #[test]
    fn parse_state_key_rejects_bad_input() {
        assert!(parse_state_key("zz").is_err());
        assert!(parse_state_key(&"ab".repeat(32)).is_ok()); // 64 hex = 32 字节
        assert!(parse_state_key(&"ab".repeat(16)).is_err()); // 32 hex = 16 字节,过短
    }

    #[test]
    fn local_state_failures_have_stable_codes() {
        let base = std::env::temp_dir().join(format!(
            "tatachat_sdk_mls_state_codes_{}",
            std::process::id()
        ));
        let _ = fs::remove_dir_all(&base);

        let storage_dir = base.join("storage");
        fs::create_dir_all(&storage_dir).expect("create storage dir");
        let storage_blob = seal_state(&[1u8; 32], b"{}", STATE_AAD_STORAGE).expect("seal");
        fs::write(storage_dir.join("openmls_storage.bin"), storage_blob).expect("write");
        let storage_error = match super::load_provider(&storage_dir, &[2u8; 32]) {
            Ok(_) => panic!("wrong storage key must fail"),
            Err(error) => error,
        };
        assert!(storage_error.starts_with(ERROR_STORAGE_AUTH));

        let invalid_dir = base.join("invalid");
        fs::create_dir_all(&invalid_dir).expect("create invalid dir");
        let invalid_blob = seal_state(&[3u8; 32], b"not-json", STATE_AAD_STORAGE).expect("seal");
        fs::write(invalid_dir.join("openmls_storage.bin"), invalid_blob).expect("write");
        let invalid_error = match super::load_provider(&invalid_dir, &[3u8; 32]) {
            Ok(_) => panic!("invalid storage must fail"),
            Err(error) => error,
        };
        assert!(invalid_error.starts_with(ERROR_STATE_INVALID));

        let device_dir = base.join("device");
        fs::create_dir_all(&device_dir).expect("create device dir");
        let device_blob = seal_state(&[4u8; 32], b"{}", STATE_AAD_DEVICE).expect("seal");
        fs::write(device_dir.join("device.bin"), device_blob).expect("write");
        let provider = super::load_provider(&device_dir, &[5u8; 32]).expect("empty provider");
        let device_error =
            super::ensure_device_signer(&provider, &device_dir, "user-a", "device-a", &[5u8; 32])
                .expect_err("wrong device key must fail");
        assert!(device_error.starts_with(ERROR_DEVICE_AUTH));

        fs::remove_dir_all(&base).expect("temporary state must be removed");
    }

    #[test]
    fn atomic_write_replaces_without_leaving_temp() {
        let dir =
            std::env::temp_dir().join(format!("tatachat_sdk_mls_atomic_{}", std::process::id()));
        let _ = fs::create_dir_all(&dir);
        let target = dir.join("state.bin");
        atomic_write(&target, b"first").expect("first write");
        assert_eq!(fs::read(&target).unwrap(), b"first");
        atomic_write(&target, b"second-longer").expect("second write");
        assert_eq!(fs::read(&target).unwrap(), b"second-longer");
        // 临时文件不得残留
        assert!(!target.with_extension("tmp").exists());
        let _ = fs::remove_dir_all(&dir);
    }
}
