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
        ProtocolMessage, ProtocolVersion, SignContent, StagedWelcome, VLBytes,
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
use openmls_traits::{
    crypto::OpenMlsCrypto, signatures::Signer, types::HashType,
    OpenMlsProvider as OpenMlsTraitsProvider,
};
use serde::{Deserialize, Serialize};
use serde_json::json;

const GMB_MLS_CIPHERSUITE: Ciphersuite = Ciphersuite::MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519;
const ERROR_STORAGE_READ: &str = "CHAT_MLS_STORAGE_READ_FAILED";
const ERROR_STATE_INVALID: &str = "CHAT_MLS_STATE_INVALID";
const ERROR_SIGNER_MISSING: &str = "CHAT_MLS_SIGNER_MISSING";
const MAX_PENDING_RESULTS: usize = 256;
const RECEIPT_LIFETIME_MILLIS: u64 = 7 * 24 * 60 * 60 * 1000;
// RFC9420应用认证扩展域；调用方不能自选标签，也不能签任意原始字节。
const AUTHENTICATION_LABEL: &str = "TataChatAuthentication";
const MAX_AUTHENTICATION_BODY_BYTES: usize = 1024 * 1024;
const MAX_JSON_INTEGER: u64 = (1 << 53) - 1;
const AUTHENTICATION_LIFETIME_MILLIS: u64 = 5 * 60 * 1000;
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
#[serde(tag = "action", rename_all = "snake_case", deny_unknown_fields)]
enum IdentityRequest {
    Initialize { state_store_dir: String, user_id: String },
    Read { state_store_dir: String, user_id: String },
    SignAuthentication {
        state_store_dir: String,
        user_id: String,
        account_id: String,
        binding_revision: u64,
        request: AuthenticationRequest,
    },
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct AuthenticationRequest {
    service_origin: String,
    challenge: String,
    expires_at_millis: u64,
    method: String,
    request_target: String,
    body_hex: String,
}

/// 只返回公开证明；正文和私钥均不进入响应或持久化结果。
#[derive(Clone, Serialize)]
struct AuthenticationProof {
    user_id: String,
    device_id: String,
    public_key: String,
    account_id: String,
    binding_revision: u64,
    service_origin: String,
    challenge: String,
    expires_at_millis: u64,
    method: String,
    request_target: String,
    body_sha256: String,
    signature: String,
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
    attachments: HashMap<String, AttachmentProgress>,
    device: DeviceRecord,
    values: HashMap<String, String>,
    results: HashMap<String, CommittedResult>,
    pending_inbound: Vec<serde_json::Value>,
}
struct MlsProvider {
    attachments: RefCell<HashMap<String, AttachmentProgress>>,
    crypto: RustCrypto,
    storage: MemoryStorage,
    device: DeviceRecord,
    results: RefCell<HashMap<String, CommittedResult>>,
    pending_inbound: RefCell<Vec<serde_json::Value>>,
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

/// 显式初始化、读取公开身份或签受限认证证明；读取/认证永不生成密钥。
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
    let (state_store_dir, user_id) = match &request {
        IdentityRequest::Initialize { state_store_dir, user_id }
        | IdentityRequest::Read { state_store_dir, user_id }
        | IdentityRequest::SignAuthentication { state_store_dir, user_id, .. } =>
            (state_store_dir, user_id),
    };
    require_identity_component(user_id)?;
    let dir = Path::new(state_store_dir);
    let _lock = lock_store(dir)?;
    let provider = match &request {
        IdentityRequest::Initialize { .. } => {
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
                    user_id: user_id.clone(),
                    device_id: public.clone(),
                    public_key: format!("0x{public}"),
                },
                results: RefCell::new(HashMap::new()),
                pending_inbound: RefCell::new(Vec::new()),
                attachments: RefCell::new(HashMap::new()),
            };
            save_provider(dir, &provider)?;
            provider
        }
        IdentityRequest::Read { .. } | IdentityRequest::SignAuthentication { .. } =>
            load_provider(dir)?,
    };
    let (_, signer) = read_device_signer(&provider, user_id, &provider.device.device_id)?;
    if let IdentityRequest::SignAuthentication { account_id, binding_revision, request, .. } =
        &request
    {
        // 同一锁下只读已有身份，不写快照、不建立群、不推进epoch或ratchet。
        let proof = authentication_proof(&provider, &signer, account_id, *binding_revision, request)?;
        return serde_json::to_string(&proof)
            .map_err(|_| authentication_error());
    }
    serde_json::to_string(&provider.device)
        .map_err(|_| state_error(ERROR_STATE_INVALID, "公开身份序列化失败"))
}

fn authentication_error() -> String {
    "CHAT_MLS_AUTHENTICATION_INVALID".into()
}

/// 规范32字节公开值；禁止大小写、无前缀和宽松解码别名。
fn authentication_hex(value: &str) -> Result<Vec<u8>, String> {
    if value.len() != 66 || !value.starts_with("0x")
        || !value[2..].bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
    {
        return Err(authentication_error());
    }
    hex::decode(&value[2..]).map_err(|_| authentication_error())
}

/// 目标是规范HTTPS源，不接受凭据/路径/查询/片段或默认端口别名。
fn validate_authentication_origin(origin: &str) -> Result<(), String> {
    let authority = origin.strip_prefix("https://").ok_or_else(authentication_error)?;
    if authority.is_empty() || authority.len() > 260
        || !authority.bytes().all(|b| b.is_ascii_graphic())
        || authority.contains(['/', '\\', '@', '?', '#'])
    {
        return Err(authentication_error());
    }
    let (host, port) = if authority.starts_with('[') {
        let end = authority.find(']').ok_or_else(authentication_error)?;
        let address = &authority[1..end];
        let parsed = address.parse::<std::net::Ipv6Addr>().map_err(|_| authentication_error())?;
        if address != parsed.to_string() {
            return Err(authentication_error());
        }
        let suffix = &authority[end + 1..];
        let port = if suffix.is_empty() { None } else {
            Some(suffix.strip_prefix(':').ok_or_else(authentication_error)?)
        };
        (&authority[..=end], port)
    } else {
        let (host, port) = match authority.split_once(':') {
            Some((host, port)) => (host, Some(port)),
            None => (authority, None),
        };
        if host.len() > 253 || host.split('.').any(|label| {
            label.is_empty() || label.len() > 63 || label.starts_with('-') || label.ends_with('-')
                || !label.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'-')
        }) {
            return Err(authentication_error());
        }
        (host, port)
    };
    if host.is_empty() {
        return Err(authentication_error());
    }
    if let Some(port) = port {
        let number = port.parse::<u16>().map_err(|_| authentication_error())?;
        if number == 0 || number == 443 || port != number.to_string() {
            return Err(authentication_error());
        }
    }
    Ok(())
}

fn validate_authentication_target(target: &str) -> Result<(), String> {
    if target.len() > 8192 || !target.starts_with('/') || target.starts_with("//")
        || !target.bytes().all(|b| b.is_ascii_graphic())
        || target.contains(['#', '\\'])
    {
        return Err(authentication_error());
    }
    let bytes = target.as_bytes();
    for (index, byte) in bytes.iter().enumerate() {
        if *byte == b'%' && (index + 2 >= bytes.len()
            || !bytes[index + 1].is_ascii_hexdigit()
            || !bytes[index + 2].is_ascii_hexdigit())
        {
            return Err(authentication_error());
        }
    }
    Ok(())
}

fn authentication_proof(
    provider: &MlsProvider,
    signer: &SignatureKeyPair,
    account_id: &str,
    binding_revision: u64,
    request: &AuthenticationRequest,
) -> Result<AuthenticationProof, String> {
    let public = authentication_hex(&provider.device.public_key)?;
    if signer.signature_scheme() != GMB_MLS_CIPHERSUITE.signature_algorithm() {
        return Err(state_error(ERROR_STATE_INVALID, "MLS签名身份算法不符"));
    }
    authentication_hex(account_id)?;
    authentication_hex(&request.challenge)?;
    validate_authentication_origin(&request.service_origin)?;
    validate_authentication_target(&request.request_target)?;
    let now = now_millis()?;
    if binding_revision > MAX_JSON_INTEGER || request.expires_at_millis > MAX_JSON_INTEGER
        || request.expires_at_millis <= now
        || request.expires_at_millis - now > AUTHENTICATION_LIFETIME_MILLIS
        || !matches!(request.method.as_str(), "GET" | "HEAD" | "POST" | "PUT" | "PATCH" | "DELETE" | "OPTIONS")
        || request.body_hex.len() > MAX_AUTHENTICATION_BODY_BYTES * 2
        || request.body_hex.len() % 2 != 0
        || !request.body_hex.bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
    {
        return Err(authentication_error());
    }
    let body = hex::decode(&request.body_hex).map_err(|_| authentication_error())?;
    let hash = provider.crypto().hash(HashType::Sha2_256, &body)
        .map_err(|_| authentication_error())?;
    let mut proof = AuthenticationProof {
        user_id: provider.device.user_id.clone(),
        device_id: provider.device.device_id.clone(),
        public_key: provider.device.public_key.clone(),
        account_id: account_id.into(),
        binding_revision,
        service_origin: request.service_origin.clone(),
        challenge: request.challenge.clone(),
        expires_at_millis: request.expires_at_millis,
        method: request.method.clone(),
        request_target: request.request_target.clone(),
        body_sha256: format!("0x{}", hex::encode(hash)),
        signature: String::new(),
    };
    // 固定结构content由原生构造，外层SignContent使用OpenMLS的标准TLS编码。
    let content = authentication_content(&proof)?;
    let encoded = SignContent::new(AUTHENTICATION_LABEL, content.into())
        .tls_serialize_detached().map_err(|_| authentication_error())?;
    let signature = signer.sign(&encoded).map_err(|_| authentication_error())?;
    // 可解析的私有材料也可能损坏；本机先验签，禁止交付与登记公钥不匹配的证明。
    provider.crypto().verify_signature(
        GMB_MLS_CIPHERSUITE.signature_algorithm(), &encoded, &public, &signature,
    ).map_err(|_| state_error(ERROR_STATE_INVALID, "MLS签名身份与公钥不匹配"))?;
    proof.signature = format!("0x{}", hex::encode(signature));
    // 签名完成后再次检查有效期，不能返回处理期间已经过期的证明。
    if proof.expires_at_millis <= now_millis()? {
        return Err(authentication_error());
    }
    Ok(proof)
}

fn authentication_content(proof: &AuthenticationProof) -> Result<Vec<u8>, String> {
    let mut content = Vec::new();
    fn text(content: &mut Vec<u8>, value: &str) -> Result<(), String> {
        VLBytes::from(value.as_bytes().to_vec()).tls_serialize(content)
            .map(|_| ()).map_err(|_| authentication_error())
    }
    text(&mut content, &proof.user_id)?;
    content.extend(authentication_hex(&format!("0x{}", proof.device_id))?);
    content.extend(authentication_hex(&proof.account_id)?);
    content.extend(proof.binding_revision.to_be_bytes());
    text(&mut content, &proof.service_origin)?;
    content.extend(authentication_hex(&proof.challenge)?);
    content.extend(proof.expires_at_millis.to_be_bytes());
    text(&mut content, &proof.method)?;
    text(&mut content, &proof.request_target)?;
    content.extend(authentication_hex(&proof.body_sha256)?);
    Ok(content)
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct StoreRequest {
    state_store_dir: String,
    user_id: String,
    action: String,
    message_id: Option<String>,
    pending_inbound: Option<serde_json::Value>,
    attachment: Option<serde_json::Value>,
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
    if !matches!(request.action.as_str(), "begin_attachment" | "attachment_progress" | "confirm_attachment_chunk" |
        "finish_attachment" | "abort_attachment") && request.attachment.is_some() {
        return Err("非附件动作禁止附件字段".into());
    }
    let response = match request.action.as_str() {
        "begin_attachment" | "attachment_progress" | "confirm_attachment_chunk" |
        "finish_attachment" | "abort_attachment" => {
            if request.message_id.is_some() || request.pending_inbound.is_some() {
                return Err("MLS附件存储禁止其他动作字段".into());
            }
            let response = attachment_store(&provider, &request.action, request.attachment.ok_or("缺少attachment")?)?;
            if request.action != "attachment_progress" { save_provider(dir, &provider)?; }
            response
        }
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
        attachments: RefCell::new(snapshot.attachments),
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
    provider.attachments.borrow_mut().retain(|_, p| {
        !p.terminal || now.saturating_sub(p.finished_at_millis.unwrap_or(now)) <= RECEIPT_LIFETIME_MILLIS
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
        attachments: provider.attachments.borrow().clone(),
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

/// 附件组只保存公开合同和紧凑游标；当前未确认块仍随results原子提交。
#[derive(Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct AttachmentProgress {
    cipher_byte_size: Option<u64>,
    cipher_sha256: Option<String>,
    welcome_sha256: Option<String>,
    plain_sha256: String,
    group_id: String,
    direction: String,
    chunk_count: u64,
    byte_size: u64,
    sender_member_identity: String,
    member_identities: Vec<String>,
    next_chunk: u64,
    durable_bytes: u64,
    durable_sha256: String,
    terminal: bool,
    created_at_millis: u64,
    finished_at_millis: Option<u64>,
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct AttachmentBegin {
    cipher_byte_size: Option<u64>,
    cipher_sha256: Option<String>,
    welcome_sha256: Option<String>,
    plain_sha256: String,
    group_id: String,
    direction: String,
    chunk_count: u64,
    byte_size: u64,
    sender_member_identity: String,
    member_identities: Vec<String>,
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct AttachmentConfirm {
    group_id: String,
    chunk_index: u64,
    durable_bytes: u64,
    durable_sha256: String,
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct AttachmentGroup {
    group_id: String,
}


#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct AttachmentChunkHeader {
    group_id: String,
    attachment_id: String,
    sender_member_identity: String,
    chunk_index: u64,
    chunk_count: u64,
    byte_size: u64,
}
/// 块头是严格业务绑定，不是自定义密码学；真正验密和发送者均来自OpenMLS。
fn validate_attachment_plaintext(provider: &MlsProvider, group: &str, plaintext: &[u8]) -> Result<(), String> {
    let records = provider.attachments.borrow();
    let Some(p) = records.get(group) else { return Ok(()) };
    if plaintext.len() < 4 { return Err("MLS附件块头截断".into()); }
    let size = u32::from_be_bytes(plaintext[..4].try_into().map_err(|_| "MLS附件块头异常")?) as usize;
    if size == 0 || size > 2044 || plaintext.len() <= 4 + size { return Err("MLS附件块头长度非法".into()); }
    let h: AttachmentChunkHeader = serde_json::from_slice(&plaintext[4..4+size]).map_err(|_| "MLS附件块头字段非法")?;
    let attachment_id = group.strip_prefix(format!("attachment:{}:",p.sender_member_identity).as_str()).ok_or("MLS附件组格式异常")?;
    let expected = std::cmp::min(1024 * 1024,p.byte_size-p.next_chunk*(1024*1024)) as usize;
    if h.group_id != group || h.attachment_id != attachment_id || h.sender_member_identity != p.sender_member_identity ||
        h.chunk_index != p.next_chunk || h.chunk_count != p.chunk_count || h.byte_size != p.byte_size ||
        plaintext.len()-4-size != expected {
        return Err("MLS附件块头绑定或顺序无效".into());
    }
    Ok(())
}

fn attachment_hex(value: &str) -> bool {
    value.len() == 64 && value.bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
}

/// 只能清除已登记的准确附件组；OpenMLS官方delete不删除共享签名身份。
fn delete_attachment_group(provider: &MlsProvider, group_id: &str) -> Result<(), String> {
    if !provider.attachments.borrow().contains_key(group_id) {
        return Err("MLS附件组未登记".into());
    }
    let id = group_id_from_conversation(group_id)?;
    if let Some(mut group) = MlsGroup::load(provider.storage(), &id)
        .map_err(|_| state_error(ERROR_STATE_INVALID, "附件组无法读取"))? {
        group.delete(provider.storage())
            .map_err(|_| state_error(ERROR_STATE_INVALID, "附件组清理失败"))?;
    }
    provider.results.borrow_mut().retain(|_, r| r.request["group_id"] != group_id);
    Ok(())
}

/// 字节落盘flush后确认一次，删除该块完整请求与结果，避免整文件随快照重复复制。
fn attachment_store(provider: &MlsProvider, action: &str, value: serde_json::Value) -> Result<serde_json::Value, String> {
    let now = now_millis()?;
    match action {
        "begin_attachment" => {
            let r: AttachmentBegin = serde_json::from_value(value).map_err(|_| "附件登记字段非法")?;
            let owner = format!("{}:{}", provider.device.user_id, provider.device.device_id);
            let expected_count = r.byte_size / (1024 * 1024) + u64::from(r.byte_size % (1024 * 1024) != 0);
            let member_set: HashSet<_> = r.member_identities.iter().collect();
            let member_bytes = serde_json::to_vec(&r.member_identities).map_err(|_| "附件名册序列化失败")?;
            if member_bytes.len() > 64 * 1024 { return Err("附件名册体积越界".into()); }
            let prefix = format!("attachment:{}:", r.sender_member_identity);
            let attachment_id = r.group_id.strip_prefix(&prefix).ok_or("附件组标识非法")?;
            // 原生入口独立复核Dart边界，异常直接输入不能写入另一种合同。
            if attachment_id.is_empty() || attachment_id.len() > 128 ||
                !attachment_id.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'_' || b == b'-') {
                return Err("附件id非法".into());
            }
            if (r.direction == "send" && (r.cipher_byte_size.is_some() || r.cipher_sha256.is_some() || r.welcome_sha256.is_some())) ||
                (r.direction == "receive" && (r.cipher_byte_size.map_or(true, |n| n <= r.byte_size || n > r.byte_size.saturating_add(expected_count.saturating_mul(4096))) ||
                    r.cipher_sha256.as_deref().map_or(true, |h| !attachment_hex(h)) ||
                    r.welcome_sha256.as_deref().map_or(true, |h| !attachment_hex(h)))) ||
                !attachment_hex(&r.plain_sha256) || r.byte_size == 0 || r.byte_size > MAX_JSON_INTEGER || r.chunk_count != expected_count || r.chunk_count > u32::MAX as u64 ||
                !matches!(r.direction.as_str(), "send" | "receive") ||
                r.group_id.len() > 320 || !r.group_id.starts_with(&format!("attachment:{}:", r.sender_member_identity)) ||
                r.member_identities.len() < 2 || r.member_identities.len() > MAX_GROUP_MEMBERS ||
                member_set.len() != r.member_identities.len() ||
                r.member_identities.windows(2).any(|m| m[0] >= m[1]) ||
                !r.member_identities.contains(&owner) || !r.member_identities.contains(&r.sender_member_identity) ||
                (r.direction == "send" && r.sender_member_identity != owner) ||
                r.member_identities.iter().any(|m| m.rsplit_once(':').map_or(true, |(u,d)| u.is_empty() || u.chars().count() > 256 || u.contains(':') || u.chars().any(|c| c <= '\u{20}') || !attachment_hex(d))) {
                return Err("MLS附件登记合同无效".into());
            }
            if let Some(saved) = provider.attachments.borrow().get(&r.group_id) {
                // 终态不再保留整份名册；返回终态仅用于明确拒绝任何继续消费。
                if saved.terminal { return Ok(json!(saved)); }
                if saved.cipher_byte_size != r.cipher_byte_size || saved.cipher_sha256 != r.cipher_sha256 ||
                    saved.welcome_sha256 != r.welcome_sha256 || saved.plain_sha256 != r.plain_sha256 || saved.direction != r.direction || saved.chunk_count != r.chunk_count || saved.byte_size != r.byte_size ||
                    saved.sender_member_identity != r.sender_member_identity || saved.member_identities != r.member_identities {
                    return Err("MLS附件登记发生变化".into());
                }
                return Ok(json!(saved));
            }
            // 过期附件仅清理其准确协议组并留七天公开终态，不能占住活跃窗口。
            let expired: Vec<_> = provider.attachments.borrow().values()
                .filter(|p| !p.terminal && now.saturating_sub(p.created_at_millis) > RECEIPT_LIFETIME_MILLIS)
                .map(|p| p.group_id.clone()).collect();
            for id in expired {
                delete_attachment_group(provider, &id)?;
                let mut records = provider.attachments.borrow_mut();
                let p = records.get_mut(&id).ok_or("附件归属缺失")?;
                p.terminal = true;
                p.member_identities.clear();
                p.finished_at_millis = Some(now);
            }
            provider.attachments.borrow_mut().retain(|_, p| !p.terminal ||
                now.saturating_sub(p.finished_at_millis.unwrap_or(now)) <= RECEIPT_LIFETIME_MILLIS);
            if provider.attachments.borrow().values().filter(|p| !p.terminal).count() >= 64 ||
                provider.attachments.borrow().len() >= 1024 {
                return Err("MLS附件协议记录已满".into());
            }
            if MlsGroup::load(provider.storage(), &group_id_from_conversation(&r.group_id)?)
                .map_err(|_| "附件状态异常")?.is_some() {
                return Err("MLS附件组已存在但没有归属收据".into());
            }
            let p = AttachmentProgress {
                cipher_byte_size:r.cipher_byte_size, cipher_sha256:r.cipher_sha256, welcome_sha256:r.welcome_sha256,
                plain_sha256: r.plain_sha256, group_id: r.group_id.clone(), direction: r.direction, chunk_count: r.chunk_count,
                byte_size: r.byte_size, sender_member_identity: r.sender_member_identity,
                member_identities: r.member_identities, next_chunk: 0, durable_bytes: 0,
                durable_sha256: String::new(), terminal: false, created_at_millis: now, finished_at_millis: None,
            };
            provider.attachments.borrow_mut().insert(r.group_id, p.clone());
            Ok(json!(p))
        }
        "attachment_progress" => {
            let r: AttachmentGroup = serde_json::from_value(value).map_err(|_| "附件查询字段非法")?;
            let records = provider.attachments.borrow();
            let p = records.get(&r.group_id).ok_or("MLS附件进度不存在")?;
            Ok(json!(p))
        }
        "confirm_attachment_chunk" => {
            let r: AttachmentConfirm = serde_json::from_value(value).map_err(|_| "附件确认字段非法")?;
            let mut records = provider.attachments.borrow_mut();
            let p = records.get_mut(&r.group_id).ok_or("MLS附件进度不存在")?;
            if p.terminal || now.saturating_sub(p.created_at_millis) > RECEIPT_LIFETIME_MILLIS ||
                !attachment_hex(&r.durable_sha256) {
                return Err("MLS附件确认无效或过期".into());
            }
            if r.chunk_index.checked_add(1) == Some(p.next_chunk) && p.durable_bytes == r.durable_bytes && p.durable_sha256 == r.durable_sha256 {
                return Ok(json!(p));
            }
            if p.next_chunk != r.chunk_index || p.next_chunk >= p.chunk_count {
                return Err("MLS附件块确认错序".into());
            }
            let kind = if p.direction == "send" { "send" } else { "process" };
            let key = format!("{kind}:{}:chunk:{}", p.group_id, p.next_chunk);
            let results = provider.results.borrow();
            let result = results.get(&key).ok_or("MLS附件原块结果缺失")?;
            if result.request["group_id"] != p.group_id || (kind == "process" &&
                (result.result["message_kind"] != "application" || result.result["status"] != "applied" ||
                result.result["sender_member_identity"] != p.sender_member_identity)) {
                return Err("MLS附件原块结果不一致".into());
            }
            let plain_len = std::cmp::min(1024 * 1024, p.byte_size - p.next_chunk * (1024 * 1024));
            let increment = if kind == "send" {
                let wire = result.result["application_wire_hex"].as_str().ok_or("MLS附件原密文缺失")?;
                let bytes = wire.len() as u64 / 2 + 4;
                if bytes <= plain_len || bytes > plain_len + 4096 { return Err("MLS附件帧开销超限".into()); }
                bytes
            } else { plain_len };
            if p.durable_bytes.checked_add(increment) != Some(r.durable_bytes) {
                return Err("MLS附件持久字节数不一致".into());
            }
            drop(results);
            provider.results.borrow_mut().remove(&key);
            p.next_chunk += 1;
            p.durable_bytes = r.durable_bytes;
            p.durable_sha256 = r.durable_sha256;
            Ok(json!(p))
        }
        "finish_attachment" | "abort_attachment" => {
            let r: AttachmentGroup = serde_json::from_value(value).map_err(|_| "附件终态字段非法")?;
            let saved = provider.attachments.borrow().get(&r.group_id).cloned().ok_or("MLS附件进度不存在")?;
            if saved.terminal { return Ok(json!(saved)); }
            if action == "finish_attachment" && saved.next_chunk != saved.chunk_count {
                return Err("MLS附件尚未持久完成".into());
            }
            delete_attachment_group(provider, &r.group_id)?;
            let mut records = provider.attachments.borrow_mut();
            let p = records.get_mut(&r.group_id).ok_or("MLS附件进度不存在")?;
            p.terminal = true;
            p.member_identities.clear();
            p.finished_at_millis = Some(now);
            Ok(json!(p))
        }
        _ => Err("MLS附件存储action非法".into()),
    }
}

/// 附件只能消费当前块；归档游标拒绝再次推进已经消费的发送/接收链。
fn require_attachment_operation(provider: &MlsProvider, kind: &str, request: &serde_json::Value) -> Result<(), String> {
    let group_id = match request["group_id"].as_str() { Some(g) => g, None => return Ok(()) };
    let records = provider.attachments.borrow();
    let Some(p) = records.get(group_id) else {
        if group_id.starts_with("attachment:") { return Err("MLS附件缺少协议归属".into()); }
        return Ok(());
    };
    if p.terminal || now_millis()?.saturating_sub(p.created_at_millis) > RECEIPT_LIFETIME_MILLIS {
        return Err("MLS附件协议已终结或过期".into());
    }
    let id = request["message_id"].as_str().ok_or("缺少message_id")?;
    let expected = match kind {
        "create" if p.direction == "send" && p.next_chunk == 0 => format!("{group_id}:create"),
        "add" if p.direction == "send" && p.next_chunk == 0 => format!("{group_id}:add"),
        "process" if p.direction == "receive" && p.next_chunk == 0 && id == format!("{group_id}:welcome") => id.to_owned(),
        "send" if p.direction == "send" && p.next_chunk < p.chunk_count => format!("{group_id}:chunk:{}", p.next_chunk),
        "process" if p.direction == "receive" && p.next_chunk < p.chunk_count => format!("{group_id}:chunk:{}", p.next_chunk),
        _ => return Err("MLS附件操作不允许".into()),
    };
    if id != expected { return Err("MLS附件操作错序".into()); }
    if request["plaintext_hex"].as_str().is_some_and(|s| s.len() > (1024 * 1024 + 2048) * 2) ||
        request["wire_message_hex"].as_str().is_some_and(|s| s.len() > (1024 * 1024 + 4096) * 2) {
        return Err("MLS附件块过大".into());
    }
    Ok(())
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
    require_attachment_operation(provider, kind, &request)?;
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
    expected_member_identities: Vec<String>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct GroupRemoveMembersRequest {
    state_store_dir: String,
    message_id: String,
    user_id: String,
    device_id: String,
    group_id: String,
    /// 按精确 user_id:device_id 设备身份移除。
    member_identities: Vec<String>,
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
    if request.key_packages_hex.is_empty() || request.key_packages_hex.len() != request.expected_member_identities.len() {
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
        let leaf = key_package.leaf_node();
        let expected = &request.expected_member_identities[index];
        let device = expected.rsplit_once(':').ok_or("成员身份格式非法")?.1;
        if identity_of(leaf.credential()) != *expected ||
            hex::encode(leaf.signature_key().as_slice()) != device ||
            prior_members.contains(expected) ||
            request.expected_member_identities.iter().filter(|id| *id == expected).count() != 1 {
            return Err("KeyPackage 与登记 MLS 身份不一致".into());
        }
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
    if request.member_identities.is_empty() {
        return Err("group_remove_members 至少需要一个精确设备身份".to_string());
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

    // 按精确设备身份移除；同 CID 的其他叶子保留。
    let targets: HashSet<&str> = request
        .member_identities
        .iter()
        .map(|value| value.as_str())
        .collect();
    if targets.len() != request.member_identities.len() {
        return Err("移除列表包含重复设备身份".to_string());
    }
    let prior_members: Vec<String> = group
        .members()
        .map(|m| identity_of(&m.credential))
        .collect();
    if targets.iter().any(|target| !prior_members.iter().any(|member| member.as_str() == *target)) {
        return Err("移除列表含不在组内的设备身份".to_string());
    }
    let mut indices = Vec::new();
    let mut removed_member_identities = HashSet::new();
    for member in group.members() {
        let identity = identity_of(&member.credential);
        if targets.contains(identity.as_str()) {
            indices.push(member.index);
            removed_member_identities.insert(identity);
        }
    }
    if indices.is_empty() {
        return Err("未在群名册中找到要移除的成员".to_string());
    }
    let mut removed_member_identities: Vec<String> = removed_member_identities.into_iter().collect();
    removed_member_identities.sort();

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
        "removed_member_identities": removed_member_identities,
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
    validate_attachment_plaintext(&provider,&request.group_id,&plaintext)?;
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
            if MlsGroup::load(provider.storage(), &group_id).map_err(|_| "MLS组加载失败")?.is_some() {
                return Err("MLS Welcome不能覆盖已消费的组".into());
            }
            let staged = StagedWelcome::new_from_welcome(
                &provider,
                mls_group_config().join_config(),
                welcome,
                None,
            )
            .map_err(|error| format!("处理群 Welcome 失败: {error:?}"))?;
            let sender_identity = identity_of(staged.welcome_sender().map_err(|_| "Welcome发送者无效")?.credential());
            // BasicCredential不是设备认证；每个实际叶子的签名公钥必须等于设备标识。
            for member in staged.members() {
                let identity = identity_of(&member.credential);
                if identity.rsplit_once(':').map_or(true, |(u,d)| u.is_empty() || u.contains(':') ||
                    !attachment_hex(d) || hex::encode(&member.signature_key) != d) {
                    return Err("MLS Welcome成员签名公钥与设备身份不一致".into());
                }
            }
            if let Some(p) = provider.attachments.borrow().get(&request.group_id) {
                let mut actual: Vec<_> = staged.members().map(|m| identity_of(&m.credential)).collect();
                actual.sort();
                if p.direction != "receive" || sender_identity != p.sender_member_identity || actual != p.member_identities {
                    return Err("MLS附件Welcome发送者或名册不一致".into());
                }
            }
            let group = staged.into_group(&provider)
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
                "sender_member_identity": sender_identity,
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

    let sender_identity = identity_of(processed.credential());
    match processed.into_content() {
        ProcessedMessageContent::ApplicationMessage(message) => {
            if let Some(p) = provider.attachments.borrow().get(conversation_id) {
                if p.direction != "receive" || sender_identity != p.sender_member_identity {
                    return Err("MLS附件实际发送者不一致".into());
                }
            }
            let plaintext = message.into_bytes();
            validate_attachment_plaintext(provider,conversation_id,&plaintext)?;
            let epoch = group.epoch().as_u64();
            Ok(json!({
                "group_id": conversation_id,
                "message_kind": "application",
                "status": "applied",
                "message_epoch": message_epoch,
                "group_epoch": epoch,
                "self_removed": false,
                "plaintext_hex": hex::encode(plaintext),
                "sender_member_identity": sender_identity,
                "member_identities": serde_json::Value::Null,
            }))
        }
        ProcessedMessageContent::StagedCommitMessage(staged) => {
            if provider.attachments.borrow().contains_key(conversation_id) { return Err("MLS附件禁止Commit".into()); }
            let self_removed = staged.self_removed();
            group
                .merge_staged_commit(provider, *staged)
                .map_err(|error| format!("合并群 Commit 失败: {error:?}"))?;
            if group.is_active() {
                for member in group.members() {
                    let identity = identity_of(&member.credential);
                    if identity.rsplit_once(':').map_or(true, |(u,d)| u.is_empty() || u.contains(':') ||
                        !attachment_hex(d) || hex::encode(&member.signature_key) != d) {
                        return Err("MLS Commit成员签名公钥与设备身份不一致".into());
                    }
                }
            }
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
                "sender_member_identity": sender_identity,
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
        add["expected_member_identities"] = json!([format!("{}:{}", b.user, b.device)]);
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

    fn authentication_request(a: &Fixture) -> serde_json::Value {
        json!({
            "state_store_dir":a.dir, "user_id":a.user, "action":"sign_authentication",
            "account_id":format!("0x{}", "11".repeat(32)), "binding_revision":1,
            "request":{
                "service_origin":"https://api.example.test",
                "challenge":format!("0x{}", "22".repeat(32)),
                "expires_at_millis":now_millis().unwrap() + 120_000,
                "method":"POST", "request_target":"/auth/session?scope=chat",
                "body_hex":hex::encode(b"synthetic request")
            }
        })
    }

    /// 验证器独立按登记合同重建字节，不调用生产authentication_content。
    fn verify_authentication(proof: &serde_json::Value, label: &str) -> bool {
        let text = |field: &str| proof[field].as_str().unwrap();
        let bytes = |field: &str| hex::decode(text(field).trim_start_matches("0x")).unwrap();
        let public = bytes("public_key");
        if text("device_id") != hex::encode(&public) {
            return false;
        }
        let mut content = Vec::new();
        VLBytes::from(text("user_id").as_bytes().to_vec()).tls_serialize(&mut content).unwrap();
        content.extend(bytes("device_id"));
        content.extend(bytes("account_id"));
        content.extend(proof["binding_revision"].as_u64().unwrap().to_be_bytes());
        VLBytes::from(text("service_origin").as_bytes().to_vec()).tls_serialize(&mut content).unwrap();
        content.extend(bytes("challenge"));
        content.extend(proof["expires_at_millis"].as_u64().unwrap().to_be_bytes());
        VLBytes::from(text("method").as_bytes().to_vec()).tls_serialize(&mut content).unwrap();
        VLBytes::from(text("request_target").as_bytes().to_vec()).tls_serialize(&mut content).unwrap();
        content.extend(bytes("body_sha256"));
        let encoded = SignContent::new(label, content.into()).tls_serialize_detached().unwrap();
        RustCrypto::default().verify_signature(
            GMB_MLS_CIPHERSUITE.signature_algorithm(), &encoded, &public, &bytes("signature"),
        ).is_ok()
    }

    #[test]
    fn authentication_reuses_persistent_identity_without_mutating_chat_state() {
        let (a, _) = pair();
        let before = fs::read(storage_path(&a.dir)).unwrap();
        let request = authentication_request(&a);
        let proof = invoke(identity_json, request.clone()).unwrap();
        assert_eq!(proof["user_id"], a.user);
        assert_eq!(proof["device_id"], a.device);
        assert_eq!(proof.as_object().unwrap().len(), 12);
        assert!(verify_authentication(&proof, AUTHENTICATION_LABEL));
        // 每次FFI重新load已提交状态，重建后仍由同一身份签相同结构。
        assert_eq!(proof, invoke(identity_json, request).unwrap());
        assert_eq!(before, fs::read(storage_path(&a.dir)).unwrap());
        let provider = load_provider(&a.dir).unwrap();
        let body_hash = provider.crypto().hash(HashType::Sha2_256, b"synthetic request").unwrap();
        assert_eq!(proof["body_sha256"], format!("0x{}", hex::encode(body_hash)));
        assert!(proof.get("body_hex").is_none());
    }

    #[test]
    fn authentication_binds_every_field_and_is_separate_from_mls_protocol_labels() {
        let a = Fixture::new("user-a");
        let proof = invoke(identity_json, authentication_request(&a)).unwrap();
        for (field, value) in [
            ("user_id", json!("other")),
            ("device_id", json!("33".repeat(32))),
            ("public_key", json!(format!("0x{}", "33".repeat(32)))),
            ("account_id", json!(format!("0x{}", "33".repeat(32)))),
            ("binding_revision", json!(2)),
            ("service_origin", json!("https://other.example.test")),
            ("challenge", json!(format!("0x{}", "33".repeat(32)))),
            ("expires_at_millis", json!(proof["expires_at_millis"].as_u64().unwrap() + 1)),
            ("method", json!("GET")),
            ("request_target", json!("/auth/other")),
            ("body_sha256", json!(format!("0x{}", "33".repeat(32)))),
            ("signature", json!(format!("0x{}", "33".repeat(64)))),
        ] {
            let mut changed = proof.clone();
            changed[field] = value;
            assert!(!verify_authentication(&changed, AUTHENTICATION_LABEL), "{field}");
        }
        for label in ["KeyPackageTBS", "LeafNodeTBS", "FramedContentTBS", "GroupInfoTBS"] {
            assert!(!verify_authentication(&proof, label), "{label}");
        }
    }

    #[test]
    fn authentication_rejects_unsafe_inputs_and_raw_signing_fields() {
        let a = Fixture::new("user-a");
        let request = authentication_request(&a);
        let before = fs::read(storage_path(&a.dir)).unwrap();
        for (field, value) in [
            ("service_origin", json!(format!("{}://api.example.test", "http"))),
            ("service_origin", json!(format!("{}://api.example.test", "ws"))),
            ("service_origin", json!("wss://api.example.test")),
            ("service_origin", json!("https://api.example.test:443")),
            ("service_origin", json!("https://user@api.example.test")),
            ("service_origin", json!("https://api.example.test/path")),
            ("service_origin", json!("https://api.example.test?query")),
            ("service_origin", json!("https://api.example.test#fragment")),
            ("service_origin", json!("https://api.example.test:0001")),
            ("request_target", json!("//other.example.test/path")),
            ("request_target", json!("/path#fragment")),
            ("request_target", json!("/path%xx")),
            ("request_target", json!("/path\nheader")),
            ("method", json!("post")),
            ("challenge", json!("22".repeat(32))),
            ("expires_at_millis", json!(0)),
            ("expires_at_millis", json!(now_millis().unwrap() + 600_000)),
            ("body_hex", json!("0")),
            ("body_hex", json!("AB")),
            ("body_hex", json!("11".repeat(MAX_AUTHENTICATION_BODY_BYTES + 1))),
            ("label", json!("FramedContentTBS")),
            ("payload_hex", json!("11")),
            ("device_id", json!("33".repeat(32))),
        ] {
            let mut changed = request.clone();
            changed["request"][field] = value;
            assert!(invoke(identity_json, changed).is_err(), "{field}");
        }
        for (field, value) in [
            ("account_id", json!("11".repeat(32))),
            ("binding_revision", json!(MAX_JSON_INTEGER + 1)),
            ("binding_revision", json!(-1)),
            ("public_key", json!(format!("0x{}", "33".repeat(32)))),
            ("action", json!("sign")),
        ] {
            let mut changed = request.clone();
            changed[field] = value;
            assert!(invoke(identity_json, changed).is_err(), "{field}");
        }
        let mut read = json!({"state_store_dir":a.dir,"user_id":a.user,"action":"read"});
        read["request"] = request["request"].clone();
        assert!(invoke(identity_json, read).is_err());
        assert_eq!(before, fs::read(storage_path(&a.dir)).unwrap());
    }

    #[test]
    fn authentication_never_replaces_missing_corrupt_or_wrong_owner_identity() {
        let a = Fixture::new("user-a");
        let request = authentication_request(&a);
        let mut other = request.clone();
        other["user_id"] = json!("other");
        assert!(invoke(identity_json, other).unwrap_err()
            .starts_with("CHAT_MLS_STATE_OWNER_MISMATCH"));
        let provider = load_provider(&a.dir).unwrap();
        let public = hex::decode(&a.device).unwrap();
        let (_, signer) = read_device_signer(&provider, &a.user, &a.device).unwrap();
        // 合成签名身份保持公钥不变，故意替换私有材料；不得返回无效签名。
        let mut corrupted = serde_json::to_value(&signer).unwrap();
        corrupted["private"] = json!(vec![0x55_u8; 32]);
        let damaged: SignatureKeyPair = serde_json::from_value(corrupted).unwrap();
        damaged.store(provider.storage()).unwrap();
        save_provider(&a.dir, &provider).unwrap();
        let damaged_signer = fs::read(storage_path(&a.dir)).unwrap();
        assert!(invoke(identity_json, request.clone()).unwrap_err()
            .starts_with(ERROR_STATE_INVALID));
        assert_eq!(damaged_signer, fs::read(storage_path(&a.dir)).unwrap());
        signer.store(provider.storage()).unwrap();
        SignatureKeyPair::delete(
            provider.storage(), &public, GMB_MLS_CIPHERSUITE.signature_algorithm(),
        ).unwrap();
        save_provider(&a.dir, &provider).unwrap();
        let missing_signer = fs::read(storage_path(&a.dir)).unwrap();
        assert!(invoke(identity_json, request.clone()).unwrap_err()
            .starts_with(ERROR_SIGNER_MISSING));
        assert_eq!(missing_signer, fs::read(storage_path(&a.dir)).unwrap());
        fs::write(storage_path(&a.dir), b"synthetic corrupt state").unwrap();
        assert!(invoke(identity_json, request.clone()).is_err());
        assert_eq!(fs::read(storage_path(&a.dir)).unwrap(), b"synthetic corrupt state");
        fs::remove_file(storage_path(&a.dir)).unwrap();
        assert!(invoke(identity_json, request).is_err());
        assert!(!storage_path(&a.dir).exists());
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
        remove["member_identities"] = json!([format!("{}:{}", b.user, b.device)]);
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


    #[test]
    fn attachment_cursor_archives_chunks_and_deletes_only_owned_protocol_group() {
        let a = Fixture::new("CID-A");
        let b = Fixture::new("CID-A");
        let sender = format!("{}:{}", a.user,a.device);
        let group = format!("attachment:{sender}:file");
        let mut members = vec![sender.clone(),format!("{}:{}",b.user,b.device)];
        members.sort();
        let config = json!({"group_id":group,"direction":"send","chunk_count":1,"byte_size":3,
            "plain_sha256":"11".repeat(32),"sender_member_identity":sender,"member_identities":members});
        let begin = json!({"state_store_dir":a.dir,"user_id":a.user,"action":"begin_attachment","attachment":config});
        invoke(store_json,begin.clone()).unwrap();
        invoke(group_create_json,a.group(&format!("{group}:create"),&group)).unwrap();
        let mut kp = b.request("package");
        kp["last_resort"] = json!(true);
        let published = invoke(create_key_package_json,kp).unwrap();
        let mut add = a.group(&format!("{group}:add"),&group);
        add["key_packages_hex"] = json!([published["key_package_hex"]]);
        add["expected_member_identities"] = json!([format!("{}:{}",b.user,b.device)]);
        invoke(group_add_members_json,add).unwrap();
        let header = serde_json::to_vec(&json!({"group_id":group,"attachment_id":"file","sender_member_identity":sender,
            "chunk_index":0,"chunk_count":1,"byte_size":3})).unwrap();
        let mut plaintext = (header.len() as u32).to_be_bytes().to_vec();
        plaintext.extend(header); plaintext.extend([1,2,3]);
        let mut request = a.group(&format!("{group}:chunk:0"),&group);
        request["plaintext_hex"] = json!(hex::encode(&plaintext));
        let first = invoke(group_create_message_json,request.clone()).unwrap();
        assert_eq!(invoke(group_create_message_json,request.clone()).unwrap(),first);
        let bytes = first["application_wire_hex"].as_str().unwrap().len()/2+4;
        let confirm = json!({"state_store_dir":a.dir,"user_id":a.user,"action":"confirm_attachment_chunk",
            "attachment":{"group_id":group,"chunk_index":0,"durable_bytes":bytes,"durable_sha256":"22".repeat(32)}});
        assert_eq!(invoke(store_json,confirm.clone()).unwrap()["next_chunk"],1);
        assert_eq!(invoke(store_json,confirm).unwrap()["next_chunk"],1);
        assert!(invoke(group_create_message_json,request).is_err());
        let pending = invoke(store_json,json!({"state_store_dir":a.dir,"user_id":a.user,"action":"pending_results",
            "message_id":format!("{group}:chunk:0")})).unwrap();
        assert!(pending["results"].as_array().unwrap().is_empty());
        invoke(group_create_json,a.group("ordinary-create","ordinary")).unwrap();
        let terminal=invoke(store_json,json!({"state_store_dir":a.dir,"user_id":a.user,"action":"finish_attachment",
            "attachment":{"group_id":group}})).unwrap();
        assert!(terminal["member_identities"].as_array().unwrap().is_empty());
        let mut read = a.group("unused",&group);
        read.as_object_mut().unwrap().remove("message_id");
        assert!(invoke(group_state_json,read).is_err());
        let identity = invoke(identity_json,json!({"state_store_dir":a.dir,"user_id":a.user,"action":"read"})).unwrap();
        assert_eq!(identity["device_id"],a.device);
        let mut ordinary = a.group("unused","ordinary");
        ordinary.as_object_mut().unwrap().remove("message_id");
        assert_eq!(invoke(group_state_json,ordinary).unwrap()["member_count"],1);
        assert!(invoke(store_json,json!({"state_store_dir":a.dir,"user_id":a.user,"action":"abort_attachment",
            "attachment":{"group_id":"ordinary"}})).is_err());
        assert!(invoke(store_json,begin).unwrap()["terminal"].as_bool().unwrap());
    }

    #[test]
    fn attachment_registration_is_closed_scoped_and_bounded() {
        let a = Fixture::new("CID-A");
        let sender = format!("{}:{}",a.user,a.device);
        let mut members = vec![sender.clone(),format!("CID-B:{}","22".repeat(32))];
        members.sort();
        for index in 0..64 {
            let config=json!({"group_id":format!("attachment:{sender}:file-{index}"),"direction":"send",
                "chunk_count":1,"byte_size":1,"plain_sha256":"11".repeat(32),
                "sender_member_identity":sender,"member_identities":members});
            invoke(store_json,json!({"state_store_dir":a.dir,"user_id":a.user,"action":"begin_attachment","attachment":config})).unwrap();
        }
        let config=json!({"group_id":format!("attachment:{sender}:overflow"),"direction":"send",
            "chunk_count":1,"byte_size":1,"plain_sha256":"11".repeat(32),
            "sender_member_identity":sender,"member_identities":members});
        assert!(invoke(store_json,json!({"state_store_dir":a.dir,"user_id":a.user,"action":"begin_attachment","attachment":config})).is_err());
        let provider=load_provider(&a.dir).unwrap();
        assert_eq!(provider.attachments.borrow().len(),64);
        assert_eq!(provider.device.device_id,a.device);
    }


    /// 直接FFI输入也须拒绝另一种附件身份、排序和整数边界，失败不能改状态。
    #[test]
    fn attachment_rejects_noncanonical_registration_and_confirmation_overflow() {
        let a=Fixture::new("CID-A");
        let sender=format!("{}:{}",a.user,a.device);
        let group=format!("attachment:{sender}:file");
        let mut members=vec![sender.clone(),format!("CID-B:{}","22".repeat(32))];
        members.sort();
        let config=json!({"group_id":group,"direction":"send","chunk_count":1,"byte_size":1,
            "plain_sha256":"11".repeat(32),"sender_member_identity":sender,"member_identities":members});
        let begin=|c| json!({"state_store_dir":a.dir,"user_id":a.user,"action":"begin_attachment","attachment":c});
        let before=fs::read(storage_path(&a.dir)).unwrap();
        for field in ["invalid-id","reverse-members","unknown","empty-welcome-digest","large-members"] {
            let mut bad=config.clone();
            match field {
                "invalid-id"=>bad["group_id"]=json!(format!("attachment:{sender}:bad.id")),
                "reverse-members"=>bad["member_identities"]=json!(members.iter().rev().collect::<Vec<_>>()),
                "unknown"=>bad["extra"]=json!(true),
                "large-members"=>{
                    let mut large=members.clone();
                    large.extend((0..1400).map(|i| format!("CID-C{i:04}:{}","33".repeat(32))));
                    large.sort();
                    bad["member_identities"]=json!(large);
                },
                _=>bad["welcome_sha256"]=json!(""),
            }
            assert!(invoke(store_json,begin(bad)).is_err());
            assert_eq!(fs::read(storage_path(&a.dir)).unwrap(),before);
        }
        invoke(store_json,begin(config)).unwrap();
        let committed=fs::read(storage_path(&a.dir)).unwrap();
        assert!(invoke(store_json,json!({"state_store_dir":a.dir,"user_id":a.user,"action":"confirm_attachment_chunk",
            "attachment":{"group_id":group,"chunk_index":u64::MAX,"durable_bytes":1,"durable_sha256":"22".repeat(32)}})).is_err());
        assert_eq!(fs::read(storage_path(&a.dir)).unwrap(),committed);
    }

    #[test]
    fn welcome_rejects_a_valid_mls_signature_with_a_forged_device_credential() {
        let a=Fixture::new("CID-A");
        let b=Fixture::new("CID-B");
        let mut request=b.request("package");
        request["last_resort"]=json!(true);
        let package=invoke(create_key_package_json,request).unwrap();
        let provider=load_provider(&a.dir).unwrap();
        let (_,signer)=read_device_signer(&provider,&a.user,&a.device).unwrap();
        let credential=CredentialWithKey {
            credential:BasicCredential::new(format!("CID-A:{}","00".repeat(32)).into_bytes()).into(),
            signature_key:signer.to_public_vec().into(),
        };
        let id=group_id_from_conversation("forged-credential").unwrap();
        let mut group=MlsGroup::new_with_group_id(&provider,&signer,&mls_group_config(),id,credential).unwrap();
        let key=KeyPackageIn::tls_deserialize_exact(hex::decode(package["key_package_hex"].as_str().unwrap()).unwrap())
            .unwrap().validate(provider.crypto(),ProtocolVersion::default()).unwrap();
        let (_,welcome,_)=group.add_members(&provider,&signer,&[key]).unwrap();
        let mut inbound=b.group("forged-welcome","forged-credential");
        inbound["wire_message_hex"]=json!(hex::encode(welcome.tls_serialize_detached().unwrap()));
        let before=fs::read(storage_path(&b.dir)).unwrap();
        assert!(invoke(group_process_json,inbound).is_err());
        assert_eq!(fs::read(storage_path(&b.dir)).unwrap(),before);
    }

}
