//! 原生内部协议与持久化回归，保持对父模块私有实现的测试访问。
use openmls_rust_crypto::OpenMlsRustCrypto;
use openmls_traits::types::SignatureScheme;

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
    fn empty(user: &str) -> Self {
        let dir = std::env::temp_dir().join(format!(
            "tatachat_mls_{}_{}",
            std::process::id(),
            SERIAL.fetch_add(1, Ordering::Relaxed)
        ));
        fs::create_dir(&dir).unwrap();
        Self {
            dir: fs::canonicalize(dir).unwrap(),
            user: user.into(),
            device: String::new(),
        }
    }
    fn new(user: &str) -> Self {
        let mut fixture = Self::empty(user);
        let identity = invoke(
            identity_json,
            json!({"state_store_dir":fixture.dir,"user_id":user,"action":"prepare"}),
        )
        .unwrap();
        fixture.device = identity["device_id"].as_str().unwrap().into();
        fixture
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
    group_pair("group")
}
fn group_pair(group: &str) -> (Fixture, Fixture) {
    let a = Fixture::new("user-a");
    let b = Fixture::new("user-b");
    let mut kp = b.request("package");
    kp["last_resort"] = json!(true);
    let published = invoke(create_key_package_json, kp).unwrap();
    invoke(group_create_json, a.group("create", group)).unwrap();
    let mut add = a.group("add", group);
    add["key_packages_hex"] = json!([published["key_package_hex"]]);
    add["expected_member_identities"] = json!([format!("{}:{}", b.user, b.device)]);
    let added = invoke(group_add_members_json, add).unwrap();
    let mut welcome = b.group("welcome", group);
    welcome["wire_message_hex"] = added["welcome_wire_hex"].clone();
    invoke(group_process_json, welcome).unwrap();
    (a, b)
}
/// 损坏密文失败时不提交快照，原合法密文仍可精确消费。
#[test]
fn corrupt_ciphertext_rejects_without_committing_or_aborting() {
    let (a, b) = pair();
    let mut send = a.group("send", "group");
    send["plaintext_hex"] = json!(hex::encode(b"synthetic ciphertext regression"));
    let sent = invoke(group_create_message_json, send).unwrap();
    let mut wire = hex::decode(sent["application_wire_hex"].as_str().unwrap()).unwrap();
    let last = wire.len() - 1;
    wire[last] ^= 1;
    let before = fs::read(storage_path(&b.dir)).unwrap();
    let mut receive = b.group("receive", "group");
    receive["wire_message_hex"] = json!(hex::encode(wire));
    assert!(invoke(group_process_json, receive.clone())
        .unwrap_err()
        .contains("CHAT_MLS_MESSAGE_REJECTED"));
    assert_eq!(before, fs::read(storage_path(&b.dir)).unwrap());
    receive["wire_message_hex"] = sent["application_wire_hex"].clone();
    assert_eq!(
        invoke(group_process_json, receive).unwrap()["plaintext_hex"],
        hex::encode(b"synthetic ciphertext regression")
    );
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
    assert_eq!(
        first,
        invoke(
            identity_json,
            json!({"state_store_dir":a.dir,"user_id":a.user,"action":"prepare"})
        )
        .unwrap()
    );
    fs::remove_file(storage_path(&a.dir)).unwrap();
    assert!(invoke(
        identity_json,
        json!({"state_store_dir":a.dir,"user_id":a.user,"action":"read"})
    )
    .is_err());
    assert!(!storage_path(&a.dir).exists());
}
#[test]
fn initialization_phase_recovers_only_unpublished_state() {
    let a = Fixture::new("phase-user");
    let original = fs::read(storage_path(&a.dir)).unwrap();
    let request = json!({"state_store_dir":a.dir,"user_id":a.user,"action":"prepare"});
    // 快照已提交但阶段/回执未完成，必须交付原身份而非重新生成。
    fs::write(
        a.dir.join("state.lock"),
        identity_phase_bytes(&a.user, b"initializing\n").unwrap(),
    )
    .unwrap();
    assert_eq!(
        invoke(identity_json, request.clone()).unwrap()["device_id"],
        a.device
    );
    assert_eq!(fs::read(storage_path(&a.dir)).unwrap(), original);
    fs::remove_file(storage_path(&a.dir)).unwrap();
    assert!(invoke(identity_json, request.clone())
        .unwrap_err()
        .starts_with(ERROR_STATE_MISSING));
    assert!(invoke(
        identity_json,
        json!({"state_store_dir":a.dir,"user_id":a.user,"action":"prepare"})
    )
    .unwrap_err()
    .starts_with(ERROR_STATE_MISSING));
    assert!(!storage_path(&a.dir).exists());
    // 仅合成尚未交付阶段可自动续行，未提交临时字节不会被当成有效快照。
    fs::write(
        a.dir.join("state.lock"),
        identity_phase_bytes(&a.user, b"initializing\n").unwrap(),
    )
    .unwrap();
    fs::write(a.dir.join("state.writing"), b"synthetic interrupted write").unwrap();
    let created = invoke(identity_json, request.clone()).unwrap();
    assert_eq!(created, invoke(identity_json, request).unwrap());
    assert_eq!(
        fs::read(a.dir.join("state.lock")).unwrap(),
        identity_phase_bytes(&a.user, b"committed\n").unwrap()
    );
}

#[test]
fn lock_phase_never_writes_through_a_hard_link() {
    let a = Fixture::new("hard-link-user");
    let path = a.dir.join("state.lock");
    let before = fs::read(&path).unwrap();
    match fs::hard_link(&path, a.dir.join("alias.lock")) {
        Ok(()) => {
            assert!(invoke(
                identity_json,
                json!({"state_store_dir":a.dir,"user_id":a.user,"action":"read"})
            )
            .is_err());
        }
        // Android shell私有测试目录由系统禁止创建硬链接；明确断言内核拒绝，不能谎称走到SDK拒绝分支。
        Err(error)
            if cfg!(target_os = "android")
                && error.kind() == std::io::ErrorKind::PermissionDenied =>
        {
            use std::os::unix::fs::MetadataExt;
            assert_eq!(fs::metadata(&path).unwrap().nlink(), 1);
            assert_eq!(
                invoke(
                    identity_json,
                    json!({"state_store_dir":a.dir,"user_id":a.user,"action":"read"})
                )
                .unwrap()["device_id"],
                a.device
            );
        }
        Err(error) => panic!("合成硬链接准备失败: {error}"),
    }
    assert_eq!(fs::read(&path).unwrap(), before);
}

#[test]
fn unpublished_initialization_phase_is_owner_scoped() {
    let a = Fixture::new("pending-owner");
    fs::remove_file(storage_path(&a.dir)).unwrap();
    fs::write(
        a.dir.join("state.lock"),
        identity_phase_bytes(&a.user, b"initializing\n").unwrap(),
    )
    .unwrap();
    assert!(invoke(
        identity_json,
        json!({"state_store_dir":a.dir,"user_id":"other-owner","action":"prepare"})
    )
    .unwrap_err()
    .starts_with("CHAT_MLS_STATE_OWNER_MISMATCH"));
    assert!(!storage_path(&a.dir).exists());
}

#[test]
fn empty_directory_after_creation_gap_prepares_once() {
    // 模拟平台已建目录、进程尚未进入原生准备即退出；已有空锁也同样处理。
    for empty_lock in [false, true] {
        let a = Fixture::empty("empty-user");
        if empty_lock {
            fs::write(a.dir.join("state.lock"), b"").unwrap();
        }
        let read = json!({"state_store_dir":a.dir,"user_id":a.user,"action":"read"});
        assert!(invoke(identity_json, read.clone())
            .unwrap_err()
            .starts_with(ERROR_STATE_MISSING));
        assert!(!storage_path(&a.dir).exists());
        let dir = a.dir.clone();
        let user = a.user.clone();
        let run = move || {
            invoke(
                identity_json,
                json!({"state_store_dir":dir,"user_id":user,"action":"prepare"}),
            )
            .unwrap()
        };
        let first = std::thread::spawn(run.clone());
        let second = std::thread::spawn(run);
        let identity = first.join().unwrap();
        assert_eq!(identity, second.join().unwrap());
        let bytes = fs::read(storage_path(&a.dir)).unwrap();
        assert_eq!(identity, invoke(identity_json, read).unwrap());
        assert_eq!(fs::read(storage_path(&a.dir)).unwrap(), bytes);
    }
}

#[test]
fn preparation_rejects_foreign_contents_and_damaged_phase() {
    let a = Fixture::empty("unpublished-user");
    let request = json!({"state_store_dir":a.dir,"user_id":a.user,"action":"prepare"});
    let foreign = a.dir.join("foreign");
    fs::write(&foreign, b"synthetic unowned state").unwrap();
    assert!(invoke(identity_json, request.clone())
        .unwrap_err()
        .starts_with(ERROR_STATE_INVALID));
    assert_eq!(fs::read(&foreign).unwrap(), b"synthetic unowned state");
    assert!(!storage_path(&a.dir).exists());
    fs::remove_file(foreign).unwrap();
    fs::write(a.dir.join("state.lock"), b"initializing\n").unwrap();
    assert!(invoke(identity_json, request)
        .unwrap_err()
        .starts_with(ERROR_STATE_INVALID));
    assert_eq!(
        fs::read(a.dir.join("state.lock")).unwrap(),
        b"initializing\n"
    );
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
        "account_id":format!("0x{}", "11".repeat(32)), "bind_rev":1,
        "request":{
            "service_origin":"https://api.example.test",
            "nonce_id":format!("0x{}", "22".repeat(32)),
            "expires_at":now_millis().unwrap() + 120_000,
            "http_method":"POST", "request_target":"/auth/session?scope=chat",
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
    VLBytes::from(text("user_id").as_bytes().to_vec())
        .tls_serialize(&mut content)
        .unwrap();
    content.extend(bytes("device_id"));
    content.extend(bytes("account_id"));
    content.extend(proof["bind_rev"].as_u64().unwrap().to_be_bytes());
    VLBytes::from(text("service_origin").as_bytes().to_vec())
        .tls_serialize(&mut content)
        .unwrap();
    content.extend(bytes("nonce_id"));
    content.extend(proof["expires_at"].as_u64().unwrap().to_be_bytes());
    VLBytes::from(text("http_method").as_bytes().to_vec())
        .tls_serialize(&mut content)
        .unwrap();
    VLBytes::from(text("request_target").as_bytes().to_vec())
        .tls_serialize(&mut content)
        .unwrap();
    content.extend(bytes("body_hash"));
    let encoded = SignContent::new(label, content.into())
        .tls_serialize_detached()
        .unwrap();
    RustCrypto::default()
        .verify_signature(
            GMB_MLS_CIPHERSUITE.signature_algorithm(),
            &encoded,
            &public,
            &bytes("signature"),
        )
        .is_ok()
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
    let body_hash = provider
        .crypto()
        .hash(HashType::Sha2_256, b"synthetic request")
        .unwrap();
    assert_eq!(proof["body_hash"], format!("0x{}", hex::encode(body_hash)));
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
        ("bind_rev", json!(2)),
        ("service_origin", json!("https://other.example.test")),
        ("nonce_id", json!(format!("0x{}", "33".repeat(32)))),
        (
            "expires_at",
            json!(proof["expires_at"].as_u64().unwrap() + 1),
        ),
        ("http_method", json!("GET")),
        ("request_target", json!("/auth/other")),
        ("body_hash", json!(format!("0x{}", "33".repeat(32)))),
        ("signature", json!(format!("0x{}", "33".repeat(64)))),
    ] {
        let mut changed = proof.clone();
        changed[field] = value;
        assert!(
            !verify_authentication(&changed, AUTHENTICATION_LABEL),
            "{field}"
        );
    }
    for label in [
        "KeyPackageTBS",
        "LeafNodeTBS",
        "FramedContentTBS",
        "GroupInfoTBS",
    ] {
        assert!(!verify_authentication(&proof, label), "{label}");
    }
}

#[test]
fn authentication_rejects_unsafe_inputs_and_raw_signing_fields() {
    let a = Fixture::new("user-a");
    let request = authentication_request(&a);
    let before = fs::read(storage_path(&a.dir)).unwrap();
    for (field, value) in [
        (
            "service_origin",
            json!(format!("{}://api.example.test", "http")),
        ),
        (
            "service_origin",
            json!(format!("{}://api.example.test", "ws")),
        ),
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
        ("http_method", json!("post")),
        ("nonce_id", json!("22".repeat(32))),
        ("expires_at", json!(0)),
        ("expires_at", json!(now_millis().unwrap() + 600_000)),
        ("body_hex", json!("0")),
        ("body_hex", json!("AB")),
        (
            "body_hex",
            json!("11".repeat(MAX_AUTHENTICATION_BODY_BYTES + 1)),
        ),
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
        ("bind_rev", json!(MAX_JSON_INTEGER + 1)),
        ("bind_rev", json!(-1)),
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
    assert!(invoke(identity_json, other)
        .unwrap_err()
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
    assert!(invoke(identity_json, request.clone())
        .unwrap_err()
        .starts_with(ERROR_STATE_INVALID));
    assert_eq!(damaged_signer, fs::read(storage_path(&a.dir)).unwrap());
    signer.store(provider.storage()).unwrap();
    SignatureKeyPair::delete(
        provider.storage(),
        &public,
        GMB_MLS_CIPHERSUITE.signature_algorithm(),
    )
    .unwrap();
    save_provider(&a.dir, &provider).unwrap();
    let missing_signer = fs::read(storage_path(&a.dir)).unwrap();
    assert!(invoke(identity_json, request.clone())
        .unwrap_err()
        .starts_with(ERROR_SIGNER_MISSING));
    assert_eq!(missing_signer, fs::read(storage_path(&a.dir)).unwrap());
    fs::write(storage_path(&a.dir), b"synthetic corrupt state").unwrap();
    assert!(invoke(identity_json, request.clone()).is_err());
    assert_eq!(
        fs::read(storage_path(&a.dir)).unwrap(),
        b"synthetic corrupt state"
    );
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
#[cfg(unix)]
#[test]
fn storage_lock_excludes_other_descriptors_and_releases_on_drop() {
    use std::os::fd::AsRawFd;
    let a = Fixture::new("lock-owner");
    let first = lock_store(&a.dir).unwrap();
    let second = fs::OpenOptions::new()
        .read(true)
        .write(true)
        .open(a.dir.join("state.lock"))
        .unwrap();
    // 系统LOCK_EX|LOCK_NB=2|4；Android也必须走真实flock，不能用std的Unsupported分支。
    assert_eq!(unsafe { flock(second.as_raw_fd(), 2 | 4) }, -1);
    assert_eq!(
        std::io::Error::last_os_error().kind(),
        std::io::ErrorKind::WouldBlock
    );
    drop(first);
    assert_eq!(unsafe { flock(second.as_raw_fd(), 2 | 4) }, 0);
    drop(second);
    drop(lock_store(&a.dir).unwrap());
}
#[test]
fn storage_lock_waits_for_owner_then_allows_authentication() {
    use std::sync::mpsc;
    use std::time::Duration;
    let a = Fixture::new("lock-owner");
    let held = lock_store(&a.dir).unwrap();
    let dir = a.dir.clone();
    let (entered, observed) = mpsc::channel();
    let (finished, done) = mpsc::channel();
    let worker = std::thread::spawn(move || {
        entered.send(()).unwrap();
        let _locked = lock_store(&dir).unwrap();
        finished.send(()).unwrap();
    });
    observed.recv_timeout(Duration::from_secs(2)).unwrap();
    assert!(matches!(
        done.recv_timeout(Duration::from_millis(100)),
        Err(mpsc::RecvTimeoutError::Timeout)
    ));
    drop(held);
    done.recv_timeout(Duration::from_secs(2)).unwrap();
    worker.join().unwrap();
    let before = fs::read(storage_path(&a.dir)).unwrap();
    let proof = invoke(identity_json, authentication_request(&a)).unwrap();
    assert_eq!(proof["device_id"], a.device);
    assert_eq!(fs::read(storage_path(&a.dir)).unwrap(), before);
}
#[test]
fn storage_lock_is_released_after_rejected_operation_without_replacing_identity() {
    let a = Fixture::new("lock-owner");
    let before = fs::read(storage_path(&a.dir)).unwrap();
    let wrong = json!({"state_store_dir":a.dir,"user_id":"wrong-owner","action":"read"});
    assert!(invoke(identity_json, wrong)
        .unwrap_err()
        .starts_with("CHAT_MLS_STATE_OWNER_MISMATCH"));
    drop(lock_store(&a.dir).unwrap());
    let read = invoke(
        identity_json,
        json!({"state_store_dir":a.dir,"user_id":a.user,"action":"read"}),
    )
    .unwrap();
    assert_eq!(read["device_id"], a.device);
    assert_eq!(fs::read(storage_path(&a.dir)).unwrap(), before);
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
    let sender = format!("{}:{}", a.user, a.device);
    let group = format!("attachment:{sender}:file");
    let mut members = vec![sender.clone(), format!("{}:{}", b.user, b.device)];
    members.sort();
    let config = json!({"group_id":group,"direction":"send","chunk_count":1,"byte_size":3,
            "plain_sha256":"11".repeat(32),"sender_member_identity":sender,"member_identities":members});
    let begin = json!({"state_store_dir":a.dir,"user_id":a.user,"action":"begin_attachment","attachment":config});
    invoke(store_json, begin.clone()).unwrap();
    invoke(
        group_create_json,
        a.group(&format!("{group}:create"), &group),
    )
    .unwrap();
    let mut kp = b.request("package");
    kp["last_resort"] = json!(true);
    let published = invoke(create_key_package_json, kp).unwrap();
    let mut add = a.group(&format!("{group}:add"), &group);
    add["key_packages_hex"] = json!([published["key_package_hex"]]);
    add["expected_member_identities"] = json!([format!("{}:{}", b.user, b.device)]);
    invoke(group_add_members_json, add).unwrap();
    let header = serde_json::to_vec(
        &json!({"group_id":group,"attachment_id":"file","sender_member_identity":sender,
            "chunk_index":0,"chunk_count":1,"byte_size":3}),
    )
    .unwrap();
    let mut plaintext = (header.len() as u32).to_be_bytes().to_vec();
    plaintext.extend(header);
    plaintext.extend([1, 2, 3]);
    let mut request = a.group(&format!("{group}:chunk:0"), &group);
    request["plaintext_hex"] = json!(hex::encode(&plaintext));
    let first = invoke(group_create_message_json, request.clone()).unwrap();
    assert_eq!(
        invoke(group_create_message_json, request.clone()).unwrap(),
        first
    );
    let bytes = first["application_wire_hex"].as_str().unwrap().len() / 2 + 4;
    let confirm = json!({"state_store_dir":a.dir,"user_id":a.user,"action":"confirm_attachment_chunk",
            "attachment":{"group_id":group,"chunk_index":0,"durable_bytes":bytes,"durable_sha256":"22".repeat(32)}});
    assert_eq!(
        invoke(store_json, confirm.clone()).unwrap()["next_chunk"],
        1
    );
    assert_eq!(invoke(store_json, confirm).unwrap()["next_chunk"], 1);
    assert!(invoke(group_create_message_json, request).is_err());
    let pending = invoke(
        store_json,
        json!({"state_store_dir":a.dir,"user_id":a.user,"action":"pending_results",
            "message_id":format!("{group}:chunk:0")}),
    )
    .unwrap();
    assert!(pending["results"].as_array().unwrap().is_empty());
    invoke(group_create_json, a.group("ordinary-create", "ordinary")).unwrap();
    let terminal = invoke(
        store_json,
        json!({"state_store_dir":a.dir,"user_id":a.user,"action":"finish_attachment",
            "attachment":{"group_id":group}}),
    )
    .unwrap();
    assert!(terminal["member_identities"].as_array().unwrap().is_empty());
    let mut read = a.group("unused", &group);
    read.as_object_mut().unwrap().remove("message_id");
    assert!(invoke(group_state_json, read).is_err());
    let identity = invoke(
        identity_json,
        json!({"state_store_dir":a.dir,"user_id":a.user,"action":"read"}),
    )
    .unwrap();
    assert_eq!(identity["device_id"], a.device);
    let mut ordinary = a.group("unused", "ordinary");
    ordinary.as_object_mut().unwrap().remove("message_id");
    assert_eq!(
        invoke(group_state_json, ordinary).unwrap()["member_count"],
        1
    );
    assert!(invoke(
        store_json,
        json!({"state_store_dir":a.dir,"user_id":a.user,"action":"abort_attachment",
            "attachment":{"group_id":"ordinary"}})
    )
    .is_err());
    assert!(invoke(store_json, begin).unwrap()["terminal"]
        .as_bool()
        .unwrap());
}

#[test]
fn attachment_registration_is_closed_scoped_and_bounded() {
    let a = Fixture::new("CID-A");
    let sender = format!("{}:{}", a.user, a.device);
    let mut members = vec![sender.clone(), format!("CID-B:{}", "22".repeat(32))];
    members.sort();
    for index in 0..64 {
        let config = json!({"group_id":format!("attachment:{sender}:file-{index}"),"direction":"send",
                "chunk_count":1,"byte_size":1,"plain_sha256":"11".repeat(32),
                "sender_member_identity":sender,"member_identities":members});
        invoke(store_json,json!({"state_store_dir":a.dir,"user_id":a.user,"action":"begin_attachment","attachment":config})).unwrap();
    }
    let config = json!({"group_id":format!("attachment:{sender}:overflow"),"direction":"send",
            "chunk_count":1,"byte_size":1,"plain_sha256":"11".repeat(32),
            "sender_member_identity":sender,"member_identities":members});
    assert!(invoke(store_json,json!({"state_store_dir":a.dir,"user_id":a.user,"action":"begin_attachment","attachment":config})).is_err());
    let provider = load_provider(&a.dir).unwrap();
    assert_eq!(provider.attachments.borrow().len(), 64);
    assert_eq!(provider.device.device_id, a.device);
}

/// 直接FFI输入也须拒绝另一种附件身份、排序和整数边界，失败不能改状态。
#[test]
fn attachment_rejects_noncanonical_registration_and_confirmation_overflow() {
    let a = Fixture::new("CID-A");
    let sender = format!("{}:{}", a.user, a.device);
    let group = format!("attachment:{sender}:file");
    let mut members = vec![sender.clone(), format!("CID-B:{}", "22".repeat(32))];
    members.sort();
    let config = json!({"group_id":group,"direction":"send","chunk_count":1,"byte_size":1,
            "plain_sha256":"11".repeat(32),"sender_member_identity":sender,"member_identities":members});
    let begin = |c| json!({"state_store_dir":a.dir,"user_id":a.user,"action":"begin_attachment","attachment":c});
    let before = fs::read(storage_path(&a.dir)).unwrap();
    for field in [
        "invalid-id",
        "reverse-members",
        "unknown",
        "empty-welcome-digest",
        "large-members",
    ] {
        let mut bad = config.clone();
        match field {
            "invalid-id" => bad["group_id"] = json!(format!("attachment:{sender}:bad.id")),
            "reverse-members" => {
                bad["member_identities"] = json!(members.iter().rev().collect::<Vec<_>>())
            }
            "unknown" => bad["extra"] = json!(true),
            "large-members" => {
                let mut large = members.clone();
                large.extend((0..1400).map(|i| format!("CID-C{i:04}:{}", "33".repeat(32))));
                large.sort();
                bad["member_identities"] = json!(large);
            }
            _ => bad["welcome_sha256"] = json!(""),
        }
        assert!(invoke(store_json, begin(bad)).is_err());
        assert_eq!(fs::read(storage_path(&a.dir)).unwrap(), before);
    }
    invoke(store_json, begin(config)).unwrap();
    let committed = fs::read(storage_path(&a.dir)).unwrap();
    assert!(invoke(store_json,json!({"state_store_dir":a.dir,"user_id":a.user,"action":"confirm_attachment_chunk",
            "attachment":{"group_id":group,"chunk_index":u64::MAX,"durable_bytes":1,"durable_sha256":"22".repeat(32)}})).is_err());
    assert_eq!(fs::read(storage_path(&a.dir)).unwrap(), committed);
}

#[test]
fn welcome_rejects_a_valid_mls_signature_with_a_forged_device_credential() {
    let a = Fixture::new("CID-A");
    let b = Fixture::new("CID-B");
    let mut request = b.request("package");
    request["last_resort"] = json!(true);
    let package = invoke(create_key_package_json, request).unwrap();
    let provider = load_provider(&a.dir).unwrap();
    let (_, signer) = read_device_signer(&provider, &a.user, &a.device).unwrap();
    let credential = CredentialWithKey {
        credential: BasicCredential::new(format!("CID-A:{}", "00".repeat(32)).into_bytes()).into(),
        signature_key: signer.to_public_vec().into(),
    };
    let id = group_id_from_conversation("forged-credential").unwrap();
    let mut group =
        MlsGroup::new_with_group_id(&provider, &signer, &mls_group_config(), id, credential)
            .unwrap();
    let key = KeyPackageIn::tls_deserialize_exact(
        hex::decode(package["key_package_hex"].as_str().unwrap()).unwrap(),
    )
    .unwrap()
    .validate(provider.crypto(), ProtocolVersion::default())
    .unwrap();
    let (_, welcome, _) = group.add_members(&provider, &signer, &[key]).unwrap();
    let mut inbound = b.group("forged-welcome", "forged-credential");
    inbound["wire_message_hex"] = json!(hex::encode(welcome.tls_serialize_detached().unwrap()));
    let before = fs::read(storage_path(&b.dir)).unwrap();
    assert!(invoke(group_process_json, inbound).is_err());
    assert_eq!(fs::read(storage_path(&b.dir)).unwrap(), before);
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct TwoPartySmokeRequest {
    plaintext: String,
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

#[test]
fn ordinary_group_rejects_member_membership_commit_before_persistence() {
    let group = "grp:user-a:permission";
    let (a, b) = group_pair(group);
    let c = Fixture::new("user-c");
    let mut kp = c.request("package");
    kp["last_resort"] = json!(true);
    let package = invoke(create_key_package_json, kp).unwrap();
    let mut add = b.group("unauthorized-add", group);
    add["key_packages_hex"] = json!([package["key_package_hex"]]);
    add["expected_member_identities"] = json!([format!("{}:{}", c.user, c.device)]);
    let sent = invoke(group_add_members_json, add).unwrap();
    let before = fs::read(storage_path(&a.dir)).unwrap();
    let mut incoming = a.group("unauthorized-commit", group);
    incoming["wire_message_hex"] = sent["commit_wire_hex"].clone();
    assert!(invoke(group_process_json, incoming)
        .unwrap_err()
        .contains("管理员"));
    assert_eq!(fs::read(storage_path(&a.dir)).unwrap(), before);
    let mut remove = a.group("admin-remove", group);
    remove["member_identities"] = json!([format!("{}:{}", b.user, b.device)]);
    assert!(invoke(group_remove_members_json, remove).is_ok());
}
