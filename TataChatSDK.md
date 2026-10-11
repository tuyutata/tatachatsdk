# TataChatSDK 技术文档

## 平台编译现场

本产品编译任务使用本仓 `target/build/<平台>` 独立临时目录，平台键为 `sdk`。不同平台同时领取并执行；同平台已有活跃任务时立即拒绝再次领取。资源准备、工程副本、缓存和编译输出只写本平台现场；确认进程及后代退出、结果被调用方消费后，删除整个平台目录。`target/build` 仅是父目录，`target/test` 仍用于独立测试。独立执行和控制台调度调用同一本仓编译入口与清理接口。


聊天SDK编译入口只负责本机编译，不提供设备安装；独立发布入口既接受调用者明确给出的源码、三端原生资产及版本坐标，也提供`local`命令在本产品固定工作根准备资源、编译三端资产并构造、验真SDK包。外部分发目的地另行确定。

## 现行编译、发布、自动化与门禁目录（2026-10-10）

本仓 `scripts/` 仅有 `build.mjs` 与 `publish.mjs`。前者拥有编译启动、原生与协议生成、工具和依赖声明、资源供给、固定工作根及同文件回归；后者拥有单一正式SDK包的构造、清单和逐件验真。普通导入不执行CLI或创建工作目录。

本机 `publish.mjs` 仅接受显式交付的源码和三端原生资产路径，构造并验真单一 SDK 包；无产物参数的 `local --run-id` 入口已删除。编译资源和原生构建只归 `build.mjs`，GitHub 自动化在自身 Workflow 中独立生成正式资产。外部分发另行授权。

```text
scripts/
├── build.mjs
└── publish.mjs
.github/
├── workflows/
│   ├── release-sdk.yml
│   └── release-sdk.mjs
└── tatagate/
    ├── tatagate.json
    └── tatagate.mjs
```

`build.mjs describe` 向控制台交付本仓的公开编译声明；独立执行和控制台调度执行同一本仓编译实现。`build.mjs native <host|android|ios|macos>` 与 `build.mjs protocol` 只属于编译入口。`.github/workflows/release-sdk.mjs` 自己完成GitHub运行中的编译、验收、组包、Tag和Release，不导入或启动两个产品脚本。`publish.mjs`的`local`入口自己准备并编译完整包；显式资产入口只处理给定包输入。`tatagate/`只读检查，不调用其它流程。

GitHub宿主测试需要在原生构建后继续加载同轮动态库：工作流只使用自身的原生编译入口与本次Runner临时目录，测试正常结束或失败退出时由工作流自身清理该目录。产品`build.mjs`不提供工作流专属保留参数，自动化也不调用本机编译入口。

现行目录替代的旧脚本、声明、包装入口和目录已删除；源码、测试、工作流、门禁登记、消费方和技术文档按现行路径核对。正式执行、资源获取、保存推送和GitHub发布仍按各自独立授权。

## 工具与依赖的声明和供给职责（2026-10-08）

本产品完全独立管理全部流程所需的工具、依赖及其它资源需求。需求唯一依据为本仓源码、公开声明、锁文件及本产品拥有的准备配方，包括准确版本、平台、官方来源、摘要或固定提交、闭包、验真方式和失败条件；塔塔控制台按当前产品声明提供资源，不维护另一份产品需求或替产品决定版本、来源与流程步骤。

本产品必须能在没有塔塔控制台时完全独立执行全部已实现流程。独立执行时，本产品自行完成可信引导、资源获取、保存、复用及任务工作视图准备，不依赖控制台源码、私有资料、安装位置或资源库。

通过塔塔控制台执行本产品流程时，本产品向控制台声明所需资源并使用其已准备好的供给。控制台先核对并复用已有的匹配工具与依赖；没有的由控制台按本产品声明下载、准备并保存到控制台工具库或依赖库，再交付本产品复用。本产品负责直接使用交付路径，不因控制台缺件或供给失败改为自行下载，也不另建同一资源的永久副本；可写包管理器视图与流程过程数据仍归本产品当前任务工作目录。

两种执行方式使用本产品同一声明、锁和流程实现，仅资源供给职责随执行方式改变。该职责适用于本产品全部平台与已实现流程；控制台本身作为产品同样适用。独立模式下资源缺失由产品处理；控制台模式下资源缺失由控制台处理。显式离线缺件、交付失败、损坏、错误摘要、来源漂移或越界必须据实失败，不自动升级、覆盖可疑原件或切换执行方式。

以上为当前职责规范；现行入口已按本仓公开接口整合，真实资源准备和完整产品验收仍须由对应流程证明。历史记录中的“可选供给”或“产品负责缺件获取”仅描述当时实现，不作为当前职责依据。

本仓现行入口以`scripts/build.mjs`及产品公开scripts实现为准；本文按日期保留的历史验收只描述当时结果，不作为当前工具、私有调用者或已撤销Publish实现的运行条件。独立塔塔门禁候选的职责和未验收状态见文末。

## 当前工作目录归属（第8步，2026-10-06）

第8、9步完成目录与路径实现、根文档迁移及测试源码维护，未运行测试、门禁、编译或安装。本文唯一原件位于<本仓根>/TataChatSDK.md；产品接口及流程直接以本仓实际代码和声明为准，业务字典库与其检查已撤销，不另建登记副本。历史验收事实不表示本轮改造已经通过验收，统一测试在第10步进行。根技术文档参与本仓门禁只读机密特征扫描，仅报告路径；真实安全验收仍由所属流程完成。


## 聊天功能的唯一产品归属

**聊天客户端的逻辑功能只能在 TataChatSDK 中实现；聊天服务端的逻辑功能只能在 CitizenServe.tatachat 中实现。公民、途遇及其他产品只依赖使用。**

TataChatSDK 是聊天客户端逻辑功能的唯一实现产品；所有消费产品需要的聊天能力与修复都必须在本产品实现，通过公开接口供宿主依赖使用。

- 消息、会话、群组、加密、协议、传输、同步、重试、聊天存储、附件、通话及聊天界面行为，按客户端与服务端职责分别归 TataChatSDK 和 CitizenServe.tatachat；新增功能、缺陷修复和平台差异也必须在所属塔塔聊天产品内完成。
- 消费产品只提供产品入口、身份与业务权益结果、服务地址及授权、主题和公开接口要求的平台配置；只通过公开接口接入，禁止复制、重写、包装成另一套聊天内核或维护产品专属聊天实现。CitizenServe.tatachat 实现通用聊天服务模块，CitizenServe.server 负责当前宿主授权装配；TuyuServe 本轮不接入聊天。
- 宿主源码与锁文件固定消费真实已保存Git提交；禁止改用邻仓工作树或改写依赖缓存。正式分发依赖塔塔聊天Release；第三方市场分发使用公开市场版本。依赖使用不以公开市场发布为前置条件。

本产品为单一sdk平台，本机工作根仅使用 `tatachatsdk/target/build/sdk` 与 `tatachatsdk/target/test`，具体边界见“本机固定执行目录”；永久工具和依赖原件按“工具与依赖的声明和供给职责”存储及复用。

当前依赖边界：TataChatSDK 的锁文件和产品脚本自行决定依赖、版本、来源及工具。塔塔控制台不扫描、不预审、不替产品选择依赖；产品可按需使用唯一 `rely/` 离线原件服务。

塔塔工具库仅保存控制台自身维护的工具，不是 TataChatSDK 的版本许可名单，也不能阻塞 SDK 的 Build、CI 或 Release。

NDK、Rust、Java、Gradle 与 Android SDK 均由 TataChatSDK 产品脚本自行选择和校验。本机 Worker 不调用工具准备器、不注入固定路径，也不以受控登记状态阻塞产品入口。

协议生成工具由tatachatsdk/scripts/build.mjs唯一声明：四端protoc固定官方35.0，Dart插件固定pub.dev官方protoc_plugin25.0.0。准备器只在调用方源码外目录验证官方归档和设置隔离PUB_CACHE；TATACHATSDK_PROTOCOL_OFFLINE=1仅消费既有普通且摘要一致的原件。固定消费者声明protoc_plugin25.0.0，使用pub get并以--enforce-lockfile回读，离线模式两次均加--offline；核对实际package_config中的插件来源与官方归档全部文件，再由dart compile exe显式读取该配置，产出当前宿主官方插件可执行文件。禁止global activate、Dart包装器、系统同名工具、版本替换及用户全局缓存。非法开关、缺失、损坏、链接或目录归档立即失败，保留既有输入与生成输出。调用方事先交付锁定Pub闭包；准备与官方插件编译仍须具体授权。build.mjs protocol继续使用两项验真的绝对工具路径，五份proto和十五份生成物保持唯一真源合同。

## 1. 产品定义

TataChatSDK 是 `tuyutata/tatachatsdk` 公开仓库独立、部署无关、多端可复用的端到端加密聊天客户端 SDK。它不解释宿主用户来自何处，不计算产品权益，不读取链，不保存宿主发送授权状态，也不持有部署凭据。

唯一加密实现为 OpenMLS。禁止并行维护第二套私聊加密、明文消息、旧消息信封或兼容传输。

## 2. 严格产品边界

TataChatSDK 负责：

- 消息、会话、设备投递和附件的通用模型。
- OpenMLS 设备身份、Last Resort KeyPackage、会话状态和群组状态。
- 运行时启动、恢复、WSS 实时同步、邮箱补拉和可靠待发队列。
- Isar 本机存储、系统保护记录、搜索索引、未读数、公开绑定代次和清理。
- 文本、表情、贴纸、语音、照片、视频和文件消息。
- 私聊与群聊的通用界面、媒体预览、录制和文件选择边界。
- 私聊语音与视频通话的客户端通用边界。
- SDK 自己的原生 OpenMLS 库、构建脚本、头文件和动态加载。

宿主负责：

- userId、accountId、绑定代次和显示名称。
- 发送资格、媒体限制和产品入口。
- 宿主业务记录的系统保护实现。
- CitizenServe.tatachat 地址、短期授权及操作系统推送能力的公开接口适配；聊天认证消费、连接、传输与唤醒后的同步逻辑由 TataChatSDK 实现。
- 产品主题、品牌文案和平台权限配置。
- 业务专属身份、发送授权、支付、位置和转账。

## 3. 当前源码结构

- tatachatsdk/lib/tatachat_sdk.dart：公开入口。
- tatachatsdk/lib/attachment：附件密文、分块和文件库。
- tatachatsdk/lib/call：私聊通话状态和客户端边界。
- tatachatsdk/lib/direct：私聊消息、附件和通话功能。
- tatachatsdk/lib/transport：WSS 控制面与同源 HTTPS 附件数据面。
- tatachatsdk/lib/core：通用消息、内容、会话与范围模型。
- tatachatsdk/lib/group：群聊模型与 OpenMLS 群流程。
- tatachatsdk/lib/mls：OpenMLS 会话、状态库和原生边界。
- tatachatsdk/lib/protocol：Protobuf 生成代码与严格编解码。
- tatachatsdk/lib/runtime：唯一运行编排、队列、同步和账户生命周期。
- tatachatsdk/lib/storage：唯一 Isar、系统保护记录、索引和公开绑定围栏。
- tatachatsdk/lib/ui：通用聊天界面。
- tatachatsdk/android、ios：SDK自己的Flutter平台插件与iOS集成资源；宿主不实现通用聊天媒体能力。
- tatachatsdk/native、native/tatachat_sdk.h、lib/protocol、scripts、test：独立原生、协议、构建与测试。

## 4. 运行时合同

ChatRuntimeCore 是唯一通用运行时。它只依赖 ChatRuntimeHost、ChatServiceTransport、ChatMediaLimitPolicy 和平台能力回调。

ChatRuntimeAccount 只携带通用字段。运行时不得出现宿主身份格式、授权等级、品牌名称或链类型。

账户上下文失效只清聊天上下文和聊天服务会话。宿主身份缓存由宿主业务流程自行管理，TataChatSDK 不得越权失效。

### 服务模块与 SDK 接入边界（2026-10-08）

通用服务模块唯一位于 CitizenServe.tatachat，当前适配 Cloudflare，Linux ARM 只预留通用接口。SDK 不读取部署资源、宿主 JWT 权益、链或服务端推送凭据；宿主通过公开 Host 合同提供短期许可和操作系统推送能力。

公开入口 `ChatSdk` 直接继承唯一 `ChatRuntimeCore`，只接收同一 `ChatRuntimeHost` 与运行依赖；
`start()` 实际调用实时同步并复用已有重连、邮箱和待发队列。重复或并发启动只登记一次；
`isRunning` 表示同步生命周期已启动，不保证网络持续在线。服务地址和短期凭证统一使用
`ChatAccess`，接收完整 WSS 入口并派生同 origin HTTPS 分块，不再提供独立身份、权限或双地址配置入口。

`stop()`/`close()` 为实例终态，先拒绝新操作，再等待初始化、回调和资源关闭；关闭失败可
重试清理，已关闭资源不会重复释放。停止不设置进程级擦除状态、不删除本机聊天历史，
继续使用需创建新实例。读取宿主账户期间关闭时，迟到结果不得重新创建实时 hub。

## 5. 消息与 OpenMLS

- 一个逻辑消息只有一个 message_id。
- 同一MLS消息生成一份协议密文，按该次提交的成员设备集合扇出投递；重试不能换用当前名册。
- 普通消息、附件消息和群消息都使用同一套 OpenMLS 边界。
- 邮箱消息必须先完成验密和本机持久化，随后才允许 ACK。
- 重复投递不得重复推进 OpenMLS 状态。
- 群聊当前禁用语音和视频通话入口。
- 不得增加重复操作编号、备用信封或并行加密分支。

## 6. 本机存储

SDK 数据根唯一为系统准备的 tatachat_sdk_data。ChatIsar 数据库名为 tatachat_sdk_chat；本地附件目录为 chat/by_user/<UTF-8用户标识hex>/attachments，文件锁与清理使用同一用户编码。MLS身份和协议状态独立位于 tatachat_sdk_mls，同一用户绑定变化不更换MLS身份。

本地正文、会话摘要、待发载荷和字符 bigram 索引保存在 SDK 自有系统保护数据库中；搜索命中后复核实际子串。附件缓存直接复制到同一受保护域，不增加应用加密密钥。缓存读写只接受绝对规范路径，点路径段及已有父项链接在创建目录之前拒绝。binding_scope由CitizenApp与TataChatSDK的实际公开接口定义，表示宿主公开隔离范围，Dart拼写为bindingScope。读写复核公开 binding_scope、user_id、account_id、binding_revision 和持久 generation；finalized 换绑在事务内保留同CID历史、更新公开绑定并清理短期队列。

iOS目录0700、文件0600，使用 completeUntilFirstUserAuthentication、排除备份、拒绝链接和越界路径并回读属性。Android使用凭据加密 noBackupFilesDir、目录0700/文件0600，拒绝设备保护区域和链接路径。保护失败终止操作。App自己的User库和公开记录由App独立实现保护，SDK不保护任意宿主路径。

旧SDK数据库文件和旧SDK附件目录按准确所有权删除，不迁移。用户清理和全量擦除保留生产者收口、跨isolate文件锁、关闭和删除回读；钱包存储不属于SDK删除范围。

### MLS持久身份与原子收发（第1步）

SDK原生生成每个user_id每台设备的一份Ed25519 MLS签名身份。device_id为该公钥的无前缀十六进制公开值；身份读取只返回user_id、device_id、public_key。私钥不导出，应用认证仅开放下文的固定结构证明。公民宿主把binding.cidNumber映射为user_id；account_id与device_id分别保持各自职责。普通MLS使用不请求钱包派生或生物识别。

公开readLocalMlsIdentity入口只读取宿主当前账户事实和本机存储，不连接服务、不查询权益。prepareMlsStorage先准备保护目录；新目录才显式初始化，已有目录必须读取。缺状态、缺签名身份、损坏或所有者不符均失败，禁止自动生成替代身份。就绪编排先读取身份、生成KeyPackage，再连接并登记；登记按实际key_package_ref确认原提交，避免跨日确认错包。

iOS使用ApplicationSupport/tatachat_sdk_mls/<UTF-8用户标识hex>，目录0700、文件0600、排除备份，秘密写入前设置并回读completeUntilFirstUserAuthentication。该保护在重启后首次解锁才允许访问，此后可支持锁屏后台处理；它属于系统文件保护，不宣称OpenMLS私钥硬件不可导出。保护语义以[Apple官方文档](https://developer.apple.com/documentation/foundation/urlfileprotection/completeuntilfirstuserauthentication)为准。Android使用应用凭据加密存储的noBackupFilesDir/tatachat_sdk_mls同一用户编码目录，必须确认用户已解锁，拒绝设备保护区域和符号链接，不创建KeyStore包装钥。各端普通MLS使用均不要求逐次生物识别。

state.bin为唯一现行快照：同一文件保存身份、OpenMLS MemoryStorage、早到密文及协议操作结果。state.lock独占锁覆盖读取、协议变更和提交；state.writing写入、文件同步、同目录rename及父目录同步构成提交。读取只采用已提交state.bin和系统保护，缺失或损坏时明确失败；普通读取不生成身份。

状态变更必须使用既有message_id，按动作种类与message_id保存精确请求和结果；同标识输入改变必须拒绝。发送状态和密文、原时间、原成员集合同时提交，重试返回原结果。接收状态与处理明文先提交，业务数据库成功后确认原生结果，再返回服务端ACK；确认后删除处理明文。stale只有精确请求存在已确认收据才允许ACK，验密失败不能伪装成重复。现有业务行的message_id存在不能代替原生精确请求复核。

pending_results无message_id时仅返回未确认结果，指定message_id时读取该操作仍保留的提交结果；未确认结果最多256项，满时明确阻止新操作且不得丢弃。确认收据从首次确认起保留七天。业务落库与原生确认不是跨库事务，由已提交结果重放及幂等业务写入补齐中断窗口。早到消息在现有队列重放时仍使用原消息message_id。

SDK用户清理和全量擦除仅删除自有MLS及数据目录，不读取或删除钱包存储。旧非钱包数据只删除，不迁移；实际删除与平台验收安排在最终统一验证。

### 同CID通讯录MLS组

MlsContactSync 使用与聊天及普通认证相同的持久MLS身份，业务交换由宿主提供，仅接受已验证的HTTPS接口。它不依赖聊天权益或聊天连接，不增加私钥。Native add_members 核对实际 KeyPackage credential、叶子签名公钥与预期 user_id:device_id；remove_members 仅接受完整、无重复且存在的精确设备叶子，聊天上层按用户展开设备列表。

CitizenServe按当前MLS会话派生CID和设备，闭集动作publish/state/reserve/commit/ack。组版本CAS、operation_id幂等和原生精确请求/结果共同覆盖提交中断。实际应用消息发送者必须与队列公开发送设备一致；application只接受operation_id、owner_cid_number和规范payload_base64，32KiB业务载荷由SDK编码后封装。业务落库后才确认原生结果，再确认设备队列；已确认原生结果的队列重放只补ACK，不重复合并或消耗发送链。新设备只能经有效成员Welcome加入；全部MLS状态丢失无法用钱包恢复旧组。未完成预留操作必须由原设备恢复，不能通过重新建组跳过已推进的协议状态。

网络附件协议替换尚属第6步；本步源变更未经运行验证。全部七步源码、注释、测试源码及残留清理完成之后统一测试与两平台真实验收。

### 同一MLS身份的受限应用认证（第2步）

唯一宿主入口为ChatRuntimeCore.createMlsAuthenticationProof(MlsAuthenticationRequest)。请求只包含service_origin、challenge、expires_at_millis、method、request_target及正文body_hex；Dart模型接收并复制不可变bodyBytes，JSON编码由SDK产生。调用方不能提供用户、设备、密钥、签名标签或任意待签字节。当前user_id、account_id与binding_revision来自宿主账户，device_id与public_key来自已存在的MLS状态。公民宿主的user_id继续是CID，SDK仍使用中性字段。

底层MlsStateStore.signAuthentication复用tatachat_sdk_mls_identity_json的sign_authentication动作；initialize、read、sign_authentication各自严格限制字段，未知字段和动作直接拒绝。认证只加载已有身份，即使目录刚创建也不初始化。丢失快照、缺签名身份、损坏、保护不符或错误所有者均失败，错误不携带账户、挑战、正文或秘密。原生还检查签名身份算法并使用登记公钥本机验签，私有材料损坏但仍可解析时也不交付证明。认证不持久化证明，不修改MLS快照、处理结果、群epoch或ratchet，不需要生物识别。

认证使用RFC9420的SignWithLabel结构，固定应用标签TataChatAuthentication，实际外层为SignContent { label&lt;V&gt; = "MLS 1.0 TataChatAuthentication", content&lt;V&gt; }，由已锁定OpenMLS的SignContent与TLS编码器生成。这是应用认证扩展，MLS协议本身不提供HTTP会话登录；CitizenServe源码使用相同认证编码并校验当前登记授权；验证统一延后。[RFC9420签名定义](https://www.rfc-editor.org/rfc/rfc9420.html#section-5.1.2)是外层编码依据。钱包业务签名合同不在本步修改范围。

content按以下顺序拼接，没有JSON字段排序或隐式地址规范化：

| 字段 | 签名字节 |
| --- | --- |
| user_id | UTF-8字节，MLS TLS &lt;V&gt;最短变长长度编码 |
| device_id | 解码后的32字节MLS公钥 |
| account_id | 解码后的32字节账户标识 |
| binding_revision | uint64大端 |
| service_origin | UTF-8字节，TLS &lt;V&gt; |
| challenge | 解码后的32字节一次性挑战 |
| expires_at_millis | uint64大端Unix毫秒 |
| method | ASCII字节，TLS &lt;V&gt; |
| request_target | 实际传输的已编码路径及查询ASCII字节，TLS &lt;V&gt; |
| body_sha256 | 原始请求正文的SHA-256，32字节 |

目标为规范HTTPS源：小写DNS标签或规范压缩IPv6，省略默认443端口，其他端口为1—65535的规范十进制；不含凭据、路径、查询或片段。服务地址不能接受HTTP/WS。WSS连接认证使用其所属HTTPS服务源及对应GET路径。方法只允许GET、HEAD、POST、PUT、PATCH、DELETE、OPTIONS。目标路径以单个/开始，最多8192字节，不能包含空白、控制字符、反斜杠、片段或非法百分号编码；验签与实际请求逐字比较，不解码再重编码。

挑战为服务端生成的32字节一次性随机数，只接受未来五分钟以内的过期时间；签名后和返回前再次检查有效期。绑定代次与时间不超过JSON精确整数上限2^53−1。认证正文最多1MiB，摘要由已有OpenMLS SHA-256计算，Dart复核相同正文摘要。该限制约束认证证明输入，不改变现有媒体上传流程。正文及证明不写日志或状态。

证明只返回user_id、device_id、public_key、account_id、binding_revision、service_origin、challenge、expires_at_millis、method、request_target、body_sha256、signature。32字节值使用小写0x加64位hex，device_id为无前缀64位hex且等于public_key去前缀；Ed25519签名为小写0x加128位hex。Dart逐项复核返回值与原请求、账户和存储身份一致，并拒绝额外字段、正文或私钥夹带。

运行时与用户文件擦除共用屏障。开始、取得存储后、签名后和文件屏障退出后重新检查宿主当前账户、CID映射、绑定代次、宿主索引、域及账户失效代次；切换、换绑、失效或关闭时不交付证明。认证过程中不连接聊天服务、不查询权益、不调用供钥能力。

CitizenServe源码验证可信登记的MLS公钥与设备关系、当前CID/账户/绑定代次、固定签名域、目标服务、实际方法/路径/正文摘要、挑战归属与有效期，并原子消费一次性挑战；App已接入同一MLS认证能力。公开公钥和自报身份不能自行取得会话，不存在认证兼容入口或回退；源码切换尚未经过全部步骤完成后的统一验证。

本步已补测试源码：原生真实验签及逐字段篡改、签名域隔离、持久身份重建、认证不改群快照、非法请求、未知字段、缺签名身份/损坏/缺快照不恢复；Dart真实FFI重建、继续MLS收发、不可变正文、返回边界和账户变化/关闭竞态。按用户要求，测试、静态分析、编译和真实验收统一延后到全部七步实现完成后执行；当前不报告本步测试通过。

## 7. 可靠投递与七天规则

- 发送先写本机待发事实，再异步执行网络操作。
- WSS 恢复后先建立实时通道，再补拉邮箱。
- 单条失败不得阻断同批其他消息。
- 附件上传失败不得阻断后续文本、表情或贴纸。
- 本机待发任务最多保留七天。
- 服务端投递最多保留七天。
- 客户端时间不决定服务端期限。
- 成功本机持久化是邮箱 ACK 的唯一前提。

## 8. 网络硬规则

允许 WSS 二进制控制与实时帧、HTTPS 附件分块。

禁止明文 HTTP、明文 WS、版本化首方路径、JSON 或明文消息回退、旧接口兼容层和第二套传输协议。

## 9. UI 边界

TataChatSDK 提供会话列表、私聊与群聊页面、消息气泡、时间、状态、未读数、输入栏、表情、贴纸、媒体选择、媒体预览、录制、发送、传输状态和私聊通话通用页面。

`ChatConversationPage` 和 `ChatConversationRoutes` 直接接收同一个 `ChatSdk`，在 SDK 内部完成发送、
待发重试、补拉、ACK、WSS、附件下载、已读和 Store 接线。宿主只能注入产品资料展示、发送资格、
错误文案和产品动作，不得再组装这些通用回调，也不得复制或替换通用会话页、运行时、存储或
OpenMLS 核心。

文件选择固定由TataChatSDK自己的附件平台插件调用Android `ACTION_OPEN_DOCUMENT`与iOS
`UIDocumentPickerViewController`；只允许一个单文件请求，取消返回空，选中内容以512MiB硬上限流式复制到
SDK系统临时目录，发送收口后删除，不改变既有附件数量、类型、大小和发送门禁。`file_picker`及其全部联邦子包
已经删除。表情、相册保存和宿主扫码闭包分别统一到`emoji_picker_flutter 4.5.4`、
`saver_gallery 5.1.0`和宿主锁定的`mobile_scanner 7.4.2`。图片缩略图继续使用
`flutter_image_compress_common 1.1.1`。上述Android实现只走AGP9内置Kotlin，不允许恢复缓存补丁、
外部Kotlin插件或第二套构建模式。

## 10. 原生边界

TataChatSDK 原生库必须独立构建、独立加载、独立测试。任何其他产品原生库都不得承担 TataChatSDK 符号保活、打包或链接职责。

- Rust crate 只输出 `cdylib` 与 `rlib`，禁止恢复 `staticlib`。
- Android 产物固定为独立 ARM64 `libtatachat_sdk.so`；宿主测试使用独立 `libtatachat_sdk.dylib`/`.so`。
  Android最终APK会裁掉普通ELF符号表，产品门禁必须用`llvm-nm -D --defined-only`核对Dart FFI实际可见的
  动态导出；每个必需OpenMLS符号只能出现一次，旧直连加密符号必须为0。Mach-O继续核对全局符号表。
- Android Flutter插件只使用Java17，负责系统单文件选择、有界临时复制，并以`MediaMetadataRetriever`读取
  视频宽高、旋转、时长；API27及以上直接生成最大边64像素的小封面，API24—26不允许先解码4K/8K整帧，
  封面安全降级为空而元数据继续返回。
- iOS 产物固定为动态 `TataChatSDK.xcframework`。`tatachat_sdk.podspec`只编译
  `TataChatSdkPlugin.swift`并引用包内Framework；本机开发只把调用方给出的源码外绝对路径转换为相对pod
  真实源根的文件模式。Swift插件只使用AVFoundation生成最大边64像素的小封面和同一组视频元数据。
- 附件平台通道固定为`chat.tata.sdk/attachment`；文件选择只返回SDK临时`path`、`file_name`和`mime`，视频探测
  一次返回`width`、`height`、`duration_ms`和受限`thumbnail_bytes`。原始URI、错误详情和设备数据不进入结果。
  旧`file_picker`、`video_compress`、`media_probe`声明、锁、通道、导入和缓存补丁禁止恢复。
- iOS Pod 同时以 `tatachat_sdk_privacy` 资源包交付 `PrivacyInfo.xcprivacy`；SDK 自身不跟踪、不采集数据，也不直接访问 Required Reason API。源码不保留宿主 Runner、Flutter 生成目录或 PluginRegistrant。
- iOS 宿主构建不创建包内临时符号链接；podspec只用相对文件模式读取源码外受控 XCFramework，二进制字节、Cargo target 和 Flutter build 全部留在调用方工作目录。
- iOS同一动态XCFramework必须同时包含ios-arm64真机和ios-arm64-simulator切片；逐片核对ARM64、OpenMLS符号和install name，并回读Xcode平台元数据。Release打包要求两个切片的二进制和Info.plist完整，任一缺失即失败。构建使用现有Rust目标和同一Xcode SDK；宿主宏使用macOS SDK，目标SDK仅通过目标专属链接参数设置。
- iOS Rust 链接阶段直接写入 `@rpath/TataChatSDK.framework/TataChatSDK`，禁止再用 `install_name_tool` 改写 Mach-O。
- Rust 1.97 的 Apple strip 路径可能生成 4 字节对齐的 `LC_SYMTAB.stroff`；iOS 构建强制 `-C strip=none` 并门禁 8 字节对齐，最终 App 的裁剪与签名交给 Xcode。
- Dart 在 iOS 通过 `DynamicLibrary.process()` 解析已经由 dyld 装载的 TataChatSDK；Smoldot 不参与 TataChatSDK 的构建、链接、导出或加载。

## 11. 测试规范

必须覆盖 OpenMLS 唯一实现、设备投递、四类消息、邮箱落盘后 ACK、重试、去重、未读、附件失败隔离、七天清理、私聊、群聊、通用 UI、公开绑定代次、系统文件保护、存储隔离以及 HTTPS/WSS 安全门禁。

生成的 chat_isar.g.dart 由 Isar 官方生成器维护；分析器只排除该生成文件自身的 experimental API 告警，手写代码仍执行严格分析。

## 2026-08-31 第 4 步：唯一 CitizenServe.tatachat 运行链路

- TataChatSDK 只保留一个具体运行传输 `内部 ChatServerConnection`。宿主只通过 `requestChatAccess` 提供服务地址、短期授权与到期时间；TataChatSDK 把授权作为不透明凭证直接交给 CitizenServe.tatachat，不解析宿主身份、产品权益或授权载荷。
- 控制与小型密文消息只走 `wss://<service-origin>/api/tatachat/realtime`，子协议固定为 `tatachat`，帧固定为二进制 Protobuf `ChatFrame`；单连接同一时刻只允许一个命令等待响应。
- 附件密文固定按 4 MiB 分块走 `https://<service-origin>/api/tatachat/attachments/{attachment_id}/chunks/{chunk_index}`，上传、下载均校验长度、分块 SHA-256 和整附件 SHA-256；附件失败不关闭 WSS，也不阻塞文字消息。
- 系统通知只接受无内容 `chat_wake`，唤醒后由同一账户运行态补拉密文邮箱；通知中不携带发送者、会话、消息或附件标识。
- 访问地址只接受无路径、无查询、无片段、无账户信息的 HTTPS 根；TataChatSDK 从该根派生 WSS 与附件路径，拒绝重定向、明文协议和第二套传输。
- 本阶段通话入口固定禁用，不增加通话信令、WebRTC 消息传输或兼容分支。
- 旧 `WssChatTransport`、`HttpsAttachmentTransport` 及宿主旧云传输已经删除；重连、KeyPackage、消息同步、ACK、推送端点和附件状态全部经过同一连接。
- 验证结果：`flutter analyze --no-pub` 零问题；Flutter 全量 156 项通过，6 项需要独立原生宿主库的既有用例明确跳过；新增传输合同 18 项通过。

## 14. 2026-08-31 第 5 步：原生库与 Smoldot 彻底解耦

- `citizenapp/smoldot/ffi` 已删除 `tatachat_sdk_native` 依赖、保活调用和 `tatachat_sdk_*` 导出；该目录源码扫描 `tatachat_sdk` 为零。
- TataChatSDK iOS 使用自己的动态 XCFramework 与二进制 CocoaPods 目标；Android 和宿主继续使用自己的动态库。
- Smoldot iOS 静态归档只保留 `smoldot_*`、`citizen_sr25519_*` 和 `account_crypto_*`，TataChatSDK 动态框架只保留 `tatachat_sdk_*`。
- TataChatSDK Flutter 全量 162 项通过且原生用例零跳过；Rust 原生 12 项、Release 打包 7 项全部通过；静态分析零问题。
- 受控 iOS Release 无签名链接构建通过，Runner 内嵌真实 `TataChatSDK.framework`；TataChatSDK 与 Smoldot 两套最终包门禁分别通过。该构建只证明编译、链接和产物合同，不冒充签名真机验收。

## 16. pub.dev 发布边界

Release生成唯一正式`tatachatsdk.tgz`，不自动执行`dart pub publish`。先前撤销的是独立外部分发；现行显式资产发布入口只构造并验真同一SDK包，不执行pub.dev或其它远端上传。实际分发目的地与凭据仍待独立决定和授权。

控制台发布动作必须交付已完成的正式资产或显式源码与三端原生资产路径；无产物参数的 local --run-id 入口已删除。Publish 不启动 Build，也不从未保存的工作树推断正式提交。

## 会话 UI 运行控制器（2026-09-01）

- `ChatConversationController` 是单会话通用 UI 状态真源，统一持有本地快照、完整性提示、媒体缓存路径、乐观气泡、发送忙碌态、已读提交、WSS 通知、轮询降级和前后台生命周期。
- `ChatConversationListController` 直接持有同一 `ChatSdk`，是会话列表通用协调真源，统一保证首次加载单飞、待发重试、同一账户只建立一个 WSS 订阅，并在实时连接不可用时执行有限轮询。
- 完整页面在 SDK 内部把控制器接到 `ChatSdk`；宿主只提供用户键、账户键和产品宿主合同。SDK 不包含具体产品的 CID 格式、会员状态、钱包、资料、主题或推送平台配置。
- 页面销毁、切换后台或离开列表时必须由控制器停止计时器和实时订阅；宿主页面禁止再实现平行的轮询或生命周期状态机。

## 第 5 步：客户端合同验收（2026-09-02）

- TataChatSDK 是唯一通用聊天客户端实现，宿主只能通过产品适配器注入短期 CitizenServe.tatachat 授权。
- 所有普通聊天消息统一使用 OpenMLS；文字、表情、贴纸与后续媒体消息不得建立第二套传输或明文旁路。
- 发件密文必须同时绑定消息编号、发送用户、发送设备、接收用户和接收设备；任一不一致在发网前失败。
- 收件邮箱必须再次校验接收用户和接收设备，跨账户或跨设备响应以 `mailbox_identity_invalid` 失败。
- 服务端消息只有在 OpenMLS 验密和本机持久化均成功后才进入 ACK 集合；失败密文保留到后续重试或七天到期。
- 推送只作为无正文唤醒信号，不作为消息载体。

## TataChatSDK 仓库身份（2026-09-02）

- TataChatSDK的源码仓库为`tuyutata/tatachatsdk`；任务身份统一为tatachatsdk.<platform>.<flow>，准确仓库操作由tuyutata组织App逐用途、单仓签发令牌。
- 仓库身份不得由模块或产品名称推测，也不得回落为 GMB；任务标题固定使用“塔塔聊天SDK”。

## 三端原生候选合同（2026-09-02）

- 产品编译器 `tatachatsdk/scripts/build.mjs native` 分离 `host`、`android`、`ios`、`macos` 四种模式；`host` 只生成本机调试库，`macos` 固定生成 ARM64 正式候选。Apple 链接参数只写入目标平台专属 Rust flags，禁止污染宿主 proc-macro。
- Rust 1.97.1 的 Release 宿主 proc-macro 单独固定为非优化、非裁剪配置，避免生成 4 字节错位而无法加载的 Mach-O；三端产品目标仍是完整优化的 Release 构建。
- 三端候选唯一闭集为 Android `libtatachat_sdk.so`、iOS `TataChatSDK.xcframework`、macOS `libtatachat_sdk.dylib`；Rust crate 不生成也不接受 iOS 静态 `.a`。
- 本机 Build 与 GitHub自动化各自拥有原生编译实现；两者不相互调用、导入或共享可写现场。各自核验其准确产物，真实运行结果不能互相替代。


## 完整会话页与宿主边界（2026-09-04）

- ChatConversationPage 是文字、表情、贴纸、图片、视频、语音、文件、下载、删除与消息渲染的唯一完整页面。
- ChatConversationPage 直接持有 ChatSdk；ChatConversationRoutes 只确定私聊/群聊标识并复用该页。发送、同步、实时通知、下载和已读链路全部由页面在 SDK 内部连接，宿主不得复制。
- ChatConversationHost 只接收产品资料标题、发送资格、错误文案、转账或位置等产品动作；SDK 不读取任何具体产品的账户、权益或业务服务。
- 具体服务连接实现为 SDK 私有 ChatServerConnection，公共 API 只暴露 ChatSdk、页面、宿主合同与必要的数据类型。
- 一个前台应用进程只持有一个 ChatSdk 实例；完整页面与路由始终复用该实例的密文仓库和网络生命周期。

## 完整页面直连 ChatSdk（2026-09-13）

- `ChatConversationPage` 的公开构造参数不再暴露文字、媒体、贴纸、同步、实时连接、附件下载、
  媒体路径和已读回调；上述能力全部从必填 `ChatSdk` 取得。
- `ChatConversationListController` 的公开构造参数不再接收宿主实时连接回调；它直接调用同一
  `ChatSdk` 完成待发重试和 WSS 生命周期，产品列表刷新仍由宿主提供。
- SDK 测试拥有完整页面和列表控制器的通用接线验证；接入产品测试只验证产品宿主边界，禁止
  复制通用会话页面测试。

## Flutter 本地依赖视图（2026-09-10）

TataChatSDK 自身的本机 Build 是纯原生构建，不额外建立没有被使用的 Flutter 视图。CitizenApp 等 Flutter 产品通过本地 `path:` 使用 TataChatSDK 时，统一工程视图递归映射 SDK 源码并保留相对依赖关系；SDK 脚本沿真实脚本路径读取源码，Cargo 和 Flutter 生成状态只写入调用产品的平台缓存。该隔离不改变 TataChatSDK 的依赖、API 或三端产物合同。

iOS podspec只消费pod根内固定相对名称`TataChatSDK.xcframework`，不接收调用方绝对路径。
正式Git包和公开包直接携带该目录；本机直接开发由消费产品在自己的源码外只读工程视图中，
把当轮Framework链接投影到SDK视图pod根的同名位置。投影不复制、移动或回写TataChatSDK源码，
CocoaPods在三种依赖形态下始终读取同一相对合同。
### 产品流程物理归属





本产品只有一个sdk目标：`build.mjs`负责本机编译，`publish.mjs`负责对明确交付的源码与原生资产构造、验真SDK包，`release-sdk.yml`与同名mjs独立负责GitHub自动化及远端Release。三个流程不相互调用；外部分发目的地另行确定。


## 扁平源码与Flutter平台布局

Android唯一Java插件和Manifest直接位于android/，包名仍为chat.tata.sdk；公共原生头文件唯一为native/tatachat_sdk.h，Framework产物仍导出Headers/tatachat_sdk.h。群界面位于lib/ui/group_views.dart，单文件测试归并到test/，不保留旧路径。

scripts/build.mjs公开createFlutterSourceView、assertFlutterSourceView及同名职责的flutter-source-view、verify-flutter-source-view命令。调用方提供互不包含的规范绝对源码根和输出根；SDK先完整核对来源，再在不存在的本轮输出目录装配Flutter标准Java包路径和Manifest。源文件只建立链接，Pub声明与锁文件使用独立普通文件，生成目录及旧Framework排除。复用前核对平台入口来源和Pub内容，拒绝链接目录、来源漂移、重复入口及旧工程叠加。Gradle继续从标准布局读取平台输入，宿主只调用接口，不复制SDK包路径规则。

## 独立公开仓库与源码根


CI 在源码外临时目录复制完整产品根并排除 Git 元数据，不把 `.git` 带入编译工程。正式包继续携带一个 `README.md`，其来源、软件版本与实际提交说明由各自组包实现只在临时包根生成并纳入 manifest 和 SHA256SUMS；包不携带编译或发布脚本，源码不新增第二份技术文档。唯一技术文档仍由本文件承载。

初始保存通过控制台现有 `test/tatachatsdk/save.sh` 与 `saveRepositories(selection=tatachatsdk)`，只创建无父 main 提交；初始源码提交与正式 Release 候选是不同事实，不得把保存冒充测试、正式签名或发布完成。
## 完整产品组织与执行合同

所有者：`tatachatsdk`，正式源码根 `<本仓根>`；本说明属于该完整产品。组件不会拆成独立仓库或目录产品。所有执行身份统一为 `产品.平台.流程`，单平台物理目录省略平台层，执行身份仍保留真实平台。

真实平台目标：`sdk`。

仓库推送仅上传本仓已经保存的main提交。控制台推送的唯一实现为console/tuisong.mjs，每仓一次生物识别，授权成功后建立独立任务，任务栏记录Git进度、准确SHA、取消及成功/失败终态。只执行Git与GitHub main只读回查，不执行源码、依赖、注释、文档、测试、签名或资源门禁；不派发产品Workflow、不运行hooks、不续签或重复认证、不自动重试、合并或强推。

本仓已移除GitHub main推送门禁触发器；main上传后不自动运行产品自动化。自动化由用户单独发起，产品仍拥有自己的Workflow、声明、资源、测试和产物实现；产品不导入控制台源码，不依赖控制台工具库、私有规则或其它仓库工作树。控制台只是可选Git客户端。各仓可独立使用公开Git接口完成仓库操作，公开SDK依赖不构成流程耦合。


技术文档由所属完整产品仓根唯一持有；私有规则和任务库由控制台私仓持有，公开产品不读取它们。公开门禁不依赖私仓资料、安装包源码、其它本机产品或个人账号；必要链真源只读本仓明确固定的公开40位SHA，不在门禁中跟随main。本机开发跨产品验收仍比较三仓已保存快照与各端真实镜像。


### 门禁与开发审查职责

准确中文注释按开发阶段逐项复核，不以每文件包含汉字作为凭证。只读门禁检查源码、临时注释、机密特征、目录及现有测试来源登记；它不执行测试，也不产生运行成功证明。保存和推送仍逐仓独立授权，编译、自动化、发布的实际结果由各自流程独立核验。

## 产品介绍与开源许可

根目录 `README.md` 仅提供本产品简明介绍，不承载技术方案、任务记录或验收结论。独立自有代码采用根 `LICENSE` 的MIT；上游代码、衍生修改、依赖及组合分发遵循各自原许可、版权、例外与附加要求。

原生第一方引擎的Cargo许可元数据与仓根MIT全文一致；OpenMLS等上游依赖保持各自原许可，禁止把项目MIT声明扩展到上游源码或依赖。

本次依赖统一同时覆盖归档差分测试的第一方smoldot C ABI适配及hex/parking_lot直接声明；对应Cargo锁与SDK冻结摘要原子同步。上游PoW与libp2p内部闭包仍按来源保留，不把第一方适配当成上游例外。全17仓直接声明回归按准确源码归属检查Cargo、Pub与npm，不只比较依赖库索引。

聊天菜单保留116逻辑像素最小宽度，以同一主题字形、文字倍率和实际图标尺寸计算必要宽度并限制在屏幕边界；正常行高仍为40基准像素，大字仅补充必要文字空间。SDK拥有基准、宽屏及大字的完整文案、边界和动作回归；App只消费锁定提交，不复制或覆盖SDK菜单。

## 附件MLS协议

附件网络密文由真正OpenMLS application message生成。每文件使用独立MLS组，复用当前CID本设备的同一持久签名身份和Last Resort KeyPackage；不得创建、导出或派生应用密钥。文件组名册取普通聊天当前获准的精确设备叶子，逐枚核验KeyPackage的credential及签名公钥。首次私聊先持久化真实Welcome并排入保序投递队列，再固定名册；Welcome和附件控制分别按精确收件设备生成稳定队列键，防止同CID不同设备互相覆盖。文件控制不能重新建会话、补新人或扩大原受众。

普通聊天MLS媒体描述包含attachment_group_id、attachment_welcome、attachment_member_identities、attachment_sender_member_identity、attachment_chat_epoch、attachment_chunk_count、明文字节数与plain_sha256，以及密文字节数与摘要。媒体protobuf采用唯一合同，数字9保留且禁止复用；未知字段、重复/非规范编码、错误成员排序、空Welcome、错组、错误块数和超过64KiB的控制描述都拒绝。附件id仅1至128位ASCII字母、数字、下划线或连字符；组标识UTF8最多320字节。成员按字典序排列且不重复，设备标识为64位小写hex；Welcome最多48KiB，块数不超过uint32，epoch和明文字节不超过安全JSON整数。Welcome由OpenMLS验证实际创建者及全部成员；SDK同时要求每个实际叶子的签名公钥等于设备标识，普通Commit提交前同样复核，不能用伪造credential引入第二个签名身份。接收块同样核验真实MLS发送者，不能用外层自报身份替代。

文件明文每块最多1MiB。块载荷由四字节业务头长度、闭集JSON头和当前明文组成；头绑定组、附件、实际发送设备、块序号、总块数、总明文字节。它只是业务绑定，全部加解密与验签由OpenMLS完成。文件帧为四字节MLS消息长度加真实MLS application字节；每帧包含业务头、MLS和长度字段的总开销最多4KiB。接收严格按序拒绝Commit、错序、缺块、多块、跨附件帧、未知字段、伪造发送者及摘要错误。原聊天的epoch、乱序窗口和发送链不被文件块推进。

每附件只保存当前未确认块结果与紧凑归档游标。原生先把MLS状态及该块完整请求/结果原子提交；Dart将原密文帧或已验密明文写入系统保护文件并flush；原生再确认游标，删除整块请求和结果。重启只续用原生精确结果或原文件持久前缀。前缀使用公开SHA256链摘要回验，每次恢复只读一次前缀；每块正常处理仅保存一块，不能复制整个文件正文到状态。已消费前缀丢失、损坏或输入改变时明确失败，不重加密、重新join、重置协议或改用其他解密路径。接收登记还固定原Welcome摘要、完整密文字节数与摘要，不允许重试替换传输事实。

最多64个活跃文件组；普通聊天和通讯录收据维持原规则，原生总未确认结果仍上限256。完整发送帧文件校验落盘后，或接收最终缓存校验提交后，调用OpenMLS官方delete删除准确所属文件组及其操作结果，清空完整名册并保留七天公开紧凑终态，终态记录总上限1024；原生登记成员列表的JSON字节总量另限制为64KiB，不能以数量上限积累任意大名册。过期活跃组只按登记归属清理，不能删除共享签名身份、普通聊天组或通讯录组。缺失协议状态不能用钱包恢复。发送组终结后只允许使用已持久控制描述；终结与控制保存之间中断且描述缺失时明确失败，不能重建同一附件组。

R2仍按固定4MiB HTTPS片段传输不透明帧文件；分块和整文件均核对长度及SHA256。对象收件CID由原附件精确成员展开，只排除本发送设备再按CID去重，同CID其他设备仍获下载授权；不从当前群镜像或单个私聊对方替换原受众。网络上传不持有本机修改屏障。上传后、创建普通聊天控制前复核当前绑定、原聊天epoch、精确名册和设备资格；名册失效则本机明确失败、清除准确待发文件和标记，远端按准确附件中止，无法立即中止的不透明对象继续受七天期限约束。已经原生提交的控制重试仅使用同一请求、原密文及原成员收据。生成控制的最终名册复核与MLS推进在同一当前绑定短屏障内；上传标记、缓存提交和所属文件清理也复核同一绑定，网络不占该屏障。创建期间名册变化时清理只要求当前绑定有效；绑定本身已失效则拒绝旧令牌写入，协议组受准确归属与七天过期清理约束。附件失败不阻塞普通聊天或邮箱ACK。

本地附件缓存仅由SDK系统保护目录承载，不再进行应用加解密。缓存提交使用临时文件flush、保护验证、rename及回读；失败不覆盖已提交缓存并删除本次残片。接收临时前缀只有最终缓存提交及协议终态成功后才删除。宿主保留媒体选择、压缩、权益、大小限制和展示策略。

SDK直接依赖cryptography已删除，锁中该无其他父依赖的包一并删除。摘要仍使用既有crypto，全部客户端秘密由同一持久MLS身份和真正OpenMLS协议内部状态持有；本地系统保护、附件和通讯录不另造应用密钥。正式生成源码必须由原有锁定protoc 35.0、protoc_plugin 25.0.0及Isar生成器产生，未完成生成与统一验证前不能宣称交付通过。

官方OpenMLS调试构建遇到损坏AEAD密文时的断言由Rust验密边界捕获为现行拒绝错误，不能跨C ABI终止宿主；失败丢弃本次内存状态，不提交快照、结果或确认，原合法密文仍可精确消费。

通讯录公开入口synchronizeContacts从同一运行实例读取已有MLS身份，复用当前公开绑定屏障；协议状态与业务应用分别持短屏障，HTTPS交换不持文件锁。不初始化替代身份，不请求聊天权益；账户、绑定、域、宿主索引和实例代次变化时拒绝迟到结果。


### 产品独立资源与编译入口


本产品平台闭集为`sdk`。调用格式为`node scripts/build.mjs <requirements|prepare|build> <platform> --work <绝对工作目录>`；requirements只读并输出唯一JSON，prepare/build从标准输入读取schema=1的资源回执。调用方交付准确工具执行器、锁定依赖目录、Git来源和归档后先prepare，再读取展开来源新增的需求，完整交付后执行build。准备、展开和编译属于同一调用工作根，各平台互不共享可写状态。独立调用方按本仓声明准备资源即可运行，无需读取其他产品工作树或私有资料。



## 2026-10-06 产品自主资源阶段（第2步）

本仓`scripts/build.mjs`拥有工具准确来源/版本/配方、递归锁解析、缺失获取、复用和本轮依赖准备；`scripts/build.mjs resources <platform> --work <绝对外部工作根>`调用同一实现，同一入口可接受空请求和显式 `--offline`；标准输入只传公开任务请求。工作根预先存在、位于源码外且不经过链接。

现存`PRODUCT_TOOL_ROOT`与`PRODUCT_DEPENDENCY_ROOT`是工具和依赖的只读路径输入，本身不能完成控制台缺件准备与交付。当前供给职责按本文“工具与依赖的声明和供给职责”执行：经控制台运行由控制台准备、保存与供给，独立运行由产品自行处理；源码外`~/.local/share/product-resources`仅描述现存独立资源存储，本轮可写状态仅在work。GNU Bash/grep/sed纳入自身需求；发行件旧Shell仅用于声明中的首次GNU构建，不进入正式PATH。下载/源码工具编译不持全局锁，最终不可变对象提交使用短锁，取消传递到工具进程组。错误摘要、损坏、未锁来源、路径越界和显式离线缺失失败并保留可疑原件。

Android固定包与修订归产品；额外平台仅消费官方固定发行来源与发行树摘要，不借宿主历史SDK目录。Maven供给只读验真后复制到独占Gradle缓存，由产品准备现有配置，消费仍离线；全库坐标导入与旧目录清理留到第5步。

`PRODUCT_WORK_DIR`、`PRODUCT_BASH_BIN`、`PRODUCT_RSYNC_BIN`及`PRODUCT_SOURCE_DIR`是公开工作/工具/工程入口；Flutter修订不读取调用方私有变量，也不回退系统rsync。旧Flutter补丁对象与当前配方不符时拒绝复用，真实替换须按准确资源操作另行授权。本步不改变编译、签名、安装及回读顺序，不修改产品UI，也未执行真实工具下载/安装。受控资源测试不能代替官方首次取得、正式编译或最终真实运行验收；第4至7步仍待逐步确认实施。

锁解析器、固定Git bundle与Pod spec/源码只在本轮固定工作根物化使用，不提交共享派生目录；可选依赖供给继续读取已登记的`objects/<SHA256>.blob`原件，独立模式按原锁取得缺件，显式离线缺原件必须失败。源码工具依赖与官方补丁仍按本产品声明准备。spec与源码按原锁在本轮使用；供给索引不决定产品版本。正式PATH排除旧POSIX Shell，`sh`对应已交付的GNU Bash。

独立缺省资源目录内`tools`保存工具发行件及工具编译输入，`rely`保存本产品声明允许的原件；锁解析器、Git bundle和Pod物化视图仅归本轮固定工作根，工具退出且结果消费后清理。根据用户最新要求，分步骤先完成实现与用例，整项解耦任务完成后统一测试；本步实施记录不等于真实工具首次取得、完整Build或安装验收通过。


### 第3步：产品完整Build入口（2026-10-06）

本产品的正式完整入口为已锁定Node的绝对路径调用`<本仓根>/scripts/build.mjs execute <platform> --work <已存在绝对工作根>`，可选`--offline`。输入stdin可为空；调用方可传schema/product_id/platform/work及真实run_id/program_digest，禁止私有变量或执行命令。入口内部完成需求→资源→准备→再次需求/资源闭包→编译→适用签名/安装/回读；独立与控制台调用同一实现。

标准输出只有唯一有界JSON：schema、product_id、platform、work、completion、files及可选真实run_id。completion沿用固定平台的device-install/macos-artifact/compile-only；files按本产品build.mjs内嵌声明登记路径和SHA256。编译日志使用stderr进入现有任务日志，不新增资源任务或任务状态。完整结果只在各阶段成功、源码/锁不漂移、工具进程确认退出后落入本轮build-result.json；同根并发或复用旧结果拒绝，取消/失联/错误身份/损坏候选不得成功。

控制台每次Build通过本产品 `build.mjs describe` 读取公开声明，调用一次execute；控制台只跟踪真实任务、核验公开结果和保存产物，不解释产品工具、依赖、编译参数或设备规则。当前控制台静态菜单、其它产品流程/安装器与程序摘要的历史耦合仍归第4步解除，本步不能当作整项解耦已完成。

本步同步完整入口、失败/取消/并发、结果/路径/摘要及适用移动端用例，但未运行测试、语法检查、编译、签名、安装或工具下载/替换；全部实现步骤完成后统一验收。源码交付与用例存在不代表真实Build已经通过。


### 第4步实施中：远端路由当前声明


本次同步路线读取、热更新和失败边界用例，未运行测试、语法检查、编译、签名、安装或下载。第4步仍在开发中：Publish执行器、聊天安装器、Start、固定菜单声明与完整程序摘要的其余实际耦合尚未解除，不能报告该步或整项任务完成。

### 产品软件记录与正式版本恢复



资源工具取消、超时、输出超限和异常收尾均等待主进程与整个后代组退出；无法确认退出时保留工作根和候选，禁止删除输入或改为可写。真实取消退出顺序用例写入build.mjs末尾用例，尚未执行。


### 产品独立资源与唯一依赖供给

本产品的scripts/build.mjs独立拥有需求解析、准备配方、来源与摘要验证、可写视图和失败条件。独立执行时由产品获取、保存与复用缺件；经控制台执行时由控制台按产品声明准备、保存并供给，产品核验并使用。PRODUCT_DEPENDENCY_ROOT仅是现存只读路径输入，缺少路径或原件不得在控制台执行模式下触发产品自行下载；实际供给接入仍需代码改造与验收。依赖索引读取仅接受schema_version=2及packages、git_sources、pods，不恢复旧目录或整锁快照。

Maven的具体JAR、AAR、POM、module及分类器文件统一由packages的group:artifact、version、准确上游URL、SHA256和SRI定位objects中的原件。产品在本轮work/dependencies/maven按上游分区复制独占文件；不复制Gradle二进制元数据、锁和下载状态。产品生成本轮GRADLE_USER_HOME/init.d初始化脚本，只在自身已声明的同源仓库之前加入本轮原件视图，缺件仍按产品原仓库解析，明确离线则失败。Gradle解析、工程状态和后续编译都属于同一产品任务。

Pod由pods中的name、version、checksum匹配当前Podfile.lock；spec保存官方CDN地址和原件摘要，source保存官方podspec来源，files保存发布树相对路径、文件内容摘要与权限或安全内部链接。只物化本产品所需的单个发布坐标；其它Pod、整锁、平台或宿主变化不要求复制全树。产品仍按CocoaPods官方规范回验SPEC CHECKSUMS，再验证本产品预锁定Git提交或HTTP发行摘要与源码回执。可写缓存和工具VERSION仅在本轮work产生，不能写回共享原件。

错来源、摘要、重复同源内容、生成状态、硬链接、内部链接越界或循环、取消及任务副本漂移均据实失败。独立与控制台调用使用同一实现；控制台只提供可选原件并跟踪原有任务，UI、功能、按钮、平台与操作顺序保持。用例源码已同步，执行留待整项实现结束后的统一测试。


### 独立入口回归验真边界

资源回归使用自带固定提交、源码字节和spec的合成Pod，不借用产品真实Pod清单提供测试输入；无真实Pod需求的平台也验证来源、摘要、链接、循环、取消和物化失败。测试现场仍位于本产品target的准确平台，不写源码或其它产品目录。资源声明与生产依赖坐标不因测试夹具改变。

资源取消对同一真实进程组每轮只发送一次信号；组不存在或Windows时才发送给主进程。仍等待主进程和后代实际退出，8秒未退出才强杀，12秒仍未确认则保留现场并失败；取消不能成为成功。


### 门禁只读边界（2026-10-10）

旧门禁中的官方归档获取、工具安装、可写工程视图、语言测试执行及测试报告器已从门禁实现删除。资源来源、版本、原锁、编译和真实测试分别由编译与自动化流程负责；门禁只读取本仓已保存源码及登记，不创建工作目录，也不清理现场。

本产品scripts/build.mjs的模块初始化与CLI执行分离：私有异步runCLI承载原命令主体，仅在直接执行文件时启动，拒绝时输出错误并以退出码1失败。模块求值先完成，scripts/build.mjs可反向导入同一checkWork、requirements和平台校验，不复制实现或增加启动入口；普通import不启动CLI。离线缺件和非法输入必须真实失败，禁止以未完成顶层await退出替代完整结果。对应真实CLI回归只在自有target测试现场替换资源供给边界，验证反向导入、参数与错误传播，不据此声称实际产品编译通过。


## 塔塔门禁只读检查

`.github/tatagate/tatagate.mjs` 是本仓独立的只读检查入口，`.github/tatagate/tatagate.json` 登记本仓身份、现行自动化和真实测试来源。`physical` 只检查真实仓根、目录闭集和自动化身份；`local` 另核对main、HTTPS origin、准确已保存提交及基线关系、文件登记、禁用平台路径、机密特征、旧入口路径与第一方临时注释。Git调用使用 `--no-optional-locks` 且仅开放读取子命令。

门禁不下载资源、不安装工具、不生成工程、不编译、不运行测试、不写入或清理`target`，也不派发GitHub自动化。登记的功能测试只做源码路径和Rust具名用例存在性核对；测试覆盖、运行结果与真实产品能力分别由编译、自动化及明确获准的验收流程证明。只读检查不能代替实际测试通过。

## 2026-10-08 服务模块接线与 lib 目录收口

lib 下直接按 attachment、call、core、direct、group、mls、protocol、runtime、storage、transport、ui 分工，公开入口保留 lib/tatachat_sdk.dart。原 src 层已删除，没有旧路径别名；五份 proto 及生成代码仅移动，不改变协议字节或存储 schema。

Host.requestChatAccess 返回 ChatAccess(realtimeUrl, accessToken, expiresAtMillis)。地址必须是完整 wss://<origin>/api/tatachat/realtime，无用户信息、查询或片段；SDK 不解析不透明 accessToken，不落盘或输出它。每次物理连接取得新许可，账户、绑定范围和修订在请求前后固定复核。附件地址由同主机/端口派生 https://<origin>/api/tatachat/attachments/{id}/chunks/{index}，TLS 和禁止重定向在实际请求上执行。

连接按代际丢弃迟到结果，等待许可、握手、Ready、当前命令各有12秒截止；队列最多128条，控制帧最多2MiB，分块最多4MiB。临近许可到期60秒即停止 socket 与所属 HTTP 请求。关闭失败保留可重试资源，不能把失败 Ready 或未回收请求当已完成关闭。系统通知只承载无正文 chat_wake。

账户补拉单飞，每批最多100条，先验密和本机精确持久收据再 ACK。字节裁剪的短批仍继续；仅空批收敛。无 ACK 进展按1/2/4秒最多三次补拉后等待下次外部触发；一轮最多32批或15秒，仍有进展时安排250毫秒后续轮次。停止、擦除和换绑拒绝旧结果及迟到 ACK；云端七天密文暂存不会替代本机永久历史。

附件沿用原待发记录的创建时间、ID、受众和密文摘要，先用幂等 complete 核对 Ready 回执；未知网络/写入/完成结果保留原密文，禁止自动 abort 或写成功标记。未得到完成证明时仅以同元数据继续 begin/分块；用户取消、受众失效或到期仍归现有终结清理入口。

本次完成源码、用例与文档准备，实际分析、测试、原生及 Worker/App 联调留第5步。门禁映射和两项生成/Release路径已按确认的最终差异正式应用：三件传输测试改名、两件连接/补拉测试纳入现有门禁，协议生成读取 lib/protocol，Release回归读取 lib/storage/system_protected_storage.dart；本次未运行这些流程。第4步实施时消费者仍为旧提交；当前公开main已有真实提交b0485cf0a2c0922791741a748fdec0a49003089f。第5步App声明与锁、Serve协议来源已统一固定该提交，协议读取lib/protocol。消费者原件物化、完整回归及真实联调须另取本轮结果，不能用本仓既有宿主验收代替。


## scripts目录与分析/ABI输入

`scripts/` 直属仅 `build.mjs`、`publish.mjs` 两个文件。原生编译、协议工具、资源供给、任务工作根和Isar宿主库定位由 `build.mjs` 实现；单一SDK发布包、来源与资产验真由 `publish.mjs` 实现。自动化及其作业入口保留在 `.github/workflows/`，只读门禁合同和检查位于 `.github/tatagate/`。根CHANGELOG.md维持删除，正式包不要求或打包它。


唯一C ABI头为native/tatachat_sdk.h，移动不改变内容或导出符号；Framework仅从此处复制。stickers/只存放48张贴纸，重复C头已删除。编译工程视图与GitHub自动化分别维护所需分析配置；Publish不装配Flutter工程或调用Build。analysis_options.yaml只写入所属临时工程，不回写源码根。

## 本机固定执行目录

本仓target是唯一生成工作边界，直属仅允许build、test两个固定目录，不建立平台、ci、release、publish或tmp固定目录；build归本机编译，test归测试。平台仍属于准确任务身份。首个文件步骤必须取得同身份短锁，核验规范真实路径、父路径无链接及活跃任务，再清空本次准确现场并回读为空；失败即停止。同产品共用固定工作根的任务串行领取，禁止共享或清理其它活动任务现场。

历史验收路径保留原记录；本节为当前本机目录合同。本次仅同步文档，不表示现有入口已通过该合同的运行验收。


## 统一联调第4步：资源验真与同文件回归

资源实现与完整回归唯一位于本仓 scripts/build.mjs，测试置于正式代码末尾；不保留独立资源测试文件、转发壳或第二测试入口文件。直接普通导入、资源准备和Build不会加载node:test或注册末尾用例。准确Node测试入口为 node --test scripts/build.mjs；直接执行 node scripts/build.mjs test 也只进入同一末尾用例。门禁只读核对functions与node_tests登记的源码路径，不执行这些测试或推断运行成功。

资源源码仍由独立开发复核检查；只读门禁仅核对本仓现存入口与登记，不抽取测试结果，也不把实现变化冒充测试通过。资源生产部分仅使用Node内置模块；末尾测试由所属编译测试入口执行，不依赖控制台私有源码。

Pod供给先验证官方spec URL、供给SHA256与CocoaPods锁checksum，再物化发布树。固定CocoaPods Core 1.16.2的Specification#checksum读取spec文件原字节SHA1；preparePods继续使用交付的准确Ruby和CocoaPods调用官方方法回读。JSON内容相等或重新序列化后的新字节不能替代锁定原件。官方实现依据为 https://github.com/CocoaPods/Core/blob/1.16.2/lib/cocoapods-core/specification.rb 。共享原件中的错误spec据实拒绝，本步不修改供给登记、锁、版本或永久原件。

两端只允许官方CDN到同一Specs路径的单跳HTTPS分发，第二次请求禁止重定向；查询、片段、凭据、错源、错路径、超限或取消均失败。独立执行按本仓锁取得，经控制台执行只核验所供原件；供给失败不隐式切成独立下载。

ZIP/TAR、受控XZ和Pod发布树物化前，在本轮独占候选内逐目录探测真实文件系统是否能保留每个准确成员名称。README与Readme以及仅大小写不同的父目录必须保留各自字节；无法表示时在写入成员前明确失败。名称不改写、不删减、不自动升级原件，取消或探测失败清理准确本轮探测目录；解包失败清理本轮目标。区分大小写工作文件系统的创建、挂载和运行须有准确授权，工作根只归本产品target/build或target/test。获准的本机临时现场为target/build/filesystem.sparseimage，64GiB稀疏区分大小写APFS，挂载点仍为target/test；镜像从已领取的test生成，保留同一占用身份，挂载后核对nonce、pid和work。命令工作目录须在镜像外，后代退出与结果消费后清理镜像内现场、卸载，再由各自公开固定根收尾删除原目录内容及镜像；卸载不确定时保留两根守卫。

SDK完整Build在本仓固定`target/build/sdk`任务根内创建`filesystem.sparseimage`（64GiB、稀疏、Case-sensitive APFS），仅挂载到同一任务的`dependencies`目录。任务占用标记、镜像文件与临时工具目录始终在挂载点外；资源供给核对当前任务和需求后、第一件工具准备前挂载，再按镜像路径和挂载点回读系统映射，并在真实挂载卷上探测`README.md`与`Readme.md`可同时保留。工具配方和原始锁共用这一本轮依赖视图。重复资源阶段只复用准确挂载，不覆盖未知镜像或其它挂载；原锁、归档名称、原件字节与固定资源来源不变。原生编译脚本的`TATACHATSDK_SOURCE_ROOT`由本产品资源环境固定为真实源码根，不接受回执或宿主覆盖。结果消费且供给进程退出后，产品公开收尾先验真并卸载本轮镜像，再删除本轮依赖视图、镜像与固定工作根；卸载或身份回读不确定时失败并保留任务守卫。独立和控制台调度均使用本仓同一资源与收尾实现。

新增及保留用例涵盖供给错锁摘要、官方分发边界、大小写目录与文件、真实名称预检取消、XZ提取失败与取消、普通导入副作用及末尾测试同步证据。合成Pod的checksum来自夹具spec准确字节，不使用假锁摘要。当前仅准备代码和用例，未执行测试、语法检查、门禁、编译、资源下载、签名、安装或真实联调，不能据此报告完整资源准备与Build通过。

本轮验证采用本仓target/test内的独立Flutter工程、锁定Pub缓存及独立Rust输出，源码根不保留.dart_tool、插件生成清单或编译产物。Node 149项及Rust 17项回归通过，宿主库实际编译用于Flutter原生回归；同步与连接夹具修正仅维护现行测试合同。完整Flutter 212项通过，0失败、0跳过；Flutter静态分析无问题；当时的原生host构建实际通过。现行原生入口为 `node scripts/build.mjs native host`。

## 当前资源供给合同（2026-10-09）

scripts/build.mjs 按本仓声明和上游锁准备、物化并复用工具与依赖；scripts/build.mjs 直接使用回执中的路径。编译流程自身管理当前任务的工具与缓存环境，塔塔门禁不参与资源准备或验真。原件库存坐标、版本声明和上游锁保留；CocoaPods与Cargo等上游包管理器仍执行自身原生流程。

供给缺件、离线缺件、工具非零退出、取消或后代未退出按实际结果失败。固定工作根、任务身份、隔离、互斥与清场合同继续适用。业务授权、钱包及链签名、TLS和正式应用产物的签名安装合同保持各自职责。

Android资源准备直接复用本产品可选工具供给的payload路径，不依赖来源证明或全树回执。Gradle与SDK可写视图只在当前已领取的target/build或target/test中的dependencies/android-sdk-view物化；工具原件只读保留。缺件、复制/执行失败及取消由入口等待工具退出后清空固定根。固定根回归scripts/build.mjs同时登记于node_tests和functions。

固定根中的工程视图按产品根的直接子项复制，排除target与既有生成目录，避免Node把整个源码根复制进自身子目录时拒绝操作。视图根仍为当前已领取工作根中的source，不成为另一个任务工作根；成功、失败和中断恢复均由本仓target入口完成清场。

### scripts 同文件回归

正式脚本与对应测试维护在同一文件，测试位于实现末尾；普通导入不注册测试。Node 回归直接使用 `node --test` 执行实现文件，本仓门禁清单按合并后的入口登记。测试工作现场仍由本产品 `scripts/build.mjs` 管理，结束后清空固定目录。

资源复用直接消费已提供路径；POSIX配方只定位实际命令，不读取系统发行身份、采集输入摘要或复验Apple资源签名。源码工具候选不再保存配方摘要与POSIX摘要证明。Maven任务视图不再扫描完整树；Pub/Cargo仍由原生命令消费原锁与校验元数据，准备器不重复比较目录摘要。

协议工具公开入口scripts/build.mjs统一由本仓资源实现准备：只接受target/build或target/test，protoc直接解包、Dart插件通过明确的DART_EXECUTABLE调用Pub和编译；不探测protoc版本或比较插件全树。单独准备成功后按本产品结果保留/finish协议交接，失败与取消清场。协议生成输出只在同轮protocol目录，不写入作为输入的lib/protocol。

资源回归的下载候选显式传入本轮test固定根，和镜像内夹具保持同卷，不借用build默认临时根。大小写名称用例在真实文件系统决定能否完整表示；已交付的libcrux-intrinsics0.0.6官方原件可经extractArchive完整展开，README.md与Readme.md必须同时保留各自原字节，不改声明、锁、上游名称或原件。此文件系统准备是临时开发现场，不修改宿主Data卷，也不表示SDK业务或正式Build已完成。


## 第3步真实本机业务复验（2026-10-09）

本轮在获准64GiB Case-sensitive APFS测试镜像内，经本仓公开resources('sdk',...)、resourceEnvironment、工程视图和runOwnedShell原生入口执行。声明与Cargo/Pub原锁不升级，源码根不产生Flutter缓存或原生编译产物。

实际失败定位与修复均进入既有文件：scripts/build.mjs把python3映射到本产品准确Python入口并优先置于PATH，避免Xcode随包Python与产品PYTHONHOME混用；已有映射漂移明确拒绝，新增实际进程回归。scripts/build.mjs的Pub原件物化按Pub实际缓存格式写入64字节校验文本，不附加换行；原件保留，复用与取消清理回归覆盖。test/transport/chat_runtime_sync_test.dart等待真实15秒批次预算后的自动补拉到空批，保留205条持久化、205次ACK与7次读取断言，不改生产预算。

实际结果：build.mjs同文件Node回归16项、当时资源实现的同文件回归45项、native/Cargo.toml all-targets原生17项、完整Flutter业务212项全部通过，0失败/跳过/取消。宿主MLS实际编译，真实MLS与Isar动态库成功加载；包含损坏密文拒绝、会话持久化与重启、附件流式处理及真实72MiB附件。现有部分RPC/推送/传输用例仍使用合成边界，此结果不代表真实云或移动设备联调。

全部子进程退出后清空本轮镜像内现场，从镜像外成功卸载；公开固定根收尾清空target/build与target/test并删除镜像，保留两个固定目录。本轮未执行正式门禁、Git保存/推送、Workflow派发、云变更、签名或安装。

## 本机编译入口

本产品完整本机编译只由scripts/build.mjs实现。声明与资源配方归本仓；独立执行自行准备，控制台发起时只消费其明确供给，不因缺件或失败切换到独立下载。控制台调用、移动端安装与macOS App约束归console/build.mjs，控制台供给的原件获取、命令执行和对象提交归tools/toolchain.mjs，产品负责自身现场与资源配方临时路径清理；供给方只收尾自己创建的候选和提交锁。

控制台调度模式用本产品入口从`node:net`的`Socket`构造实际FD4双向资源通道；需求与资源准备两轮都通过同一通道请求，回执拒绝或断管立即失败，绝不改走独立获取。同文件Node回归以真实子进程FD4和合成供给方覆盖两轮正常交付、拒绝、断管及按任务编号收尾，避免只注入客户端替身而遗漏通道建立分支。

公开编译组件只有本文件中的正文；本机编译不生成第二份脚本。公开SDK依赖按本仓原锁消费，不读取兄弟仓本机检出或调度兄弟仓任务。GitHub自动化的原生编译、测试、组包与Release由同名工作流自己执行，不调用本机编译或独立发布入口。

## GitHub自动化

本仓自动化只在GitHub的main源码上执行；控制台只调用与展示。各目标独立拥有同名的YAML与Node实现，不调用其他仓或其他目标的Workflow。版本、构建、测试、签名、完整产物核验与正式tag/Release均由本仓负责。

- `.github/workflows/release-sdk.yml`及同名`.mjs`。

每个目标的最后任务使用always读取所有前置结果：全部成功清本仓本目标旧成功，否则清旧失败并失败退出。仅保留最新成功、最新失败各一条；保护本次Run和所有活动任务，另一类结果与其他目标不受影响。删除关联正式Release、tag、Actions产物和Run后回查；任何清理错误都按实际失败报告，不自动重试。

SDK是一个完整包、一个sdk目标。内部组件属于该包的完整构建与验收，不产生系统级自动化入口或独立版本产物。固定SDK源码依赖仍由消费仓声明和锁管理，历史成功/失败产物清理由生产仓负责。

所属回归位于各目标同名mjs，覆盖前置结果、版本边界、平台隔离、活动保护和完整分页；真实GitHub构建与发布验收依任务授权另行执行。

调度方按本仓supplyRequirements和prepareToolSupply取得工具候选；调度模式的获取、提交及执行使用供给方交付的能力；产品配方自行清理自己的临时生成物。缓存复用消费实际路径，运行Node版本/字节、Apple资源签名及工具全树复验不作为本机编译门禁；上游锁与正式应用签名、安装回读继续由各自真实流程执行。

本机编译现场由本产品领取和收尾。调度任务编号随本产品领取记录保存；本轮结果消费后，只允许匹配该编号的收尾请求。产品确认自身进程及资源供给后代全部退出后才清场；异常、编号不符或退出未确认时保留现场。控制台只持有调度锁、调用本产品入口并供给资源，不实现产品清理。

软件版本计算使用本目标GitHub运行序号作为单调下界，并与本仓已成功版本比较；失败或历史清理不使版本返回源码初值。版本只在GitHub本次运行内产生，同一Run重试保持运行序号，Tag另绑定准确attempt。


### 当前自动化最后处理

本仓每个自动化目标仅由自身release-<平台>.yml与同名mjs执行，最后处理依赖全部前置任务。清理只接受该目标准确Workflow路径、main和手动事件，不根据已删除文件或旧入口名称猜测归属。前置失败时，本次产物撤销与旧失败清理分别尝试并汇总错误；任何一项未确认均失败。SDK目标内部组件共同组成一个完整包，不作为独立发布平台。固定依赖仍由本仓声明和原锁管理，不参加自产历史结果分类。


### 本仓 GitHub 自动化与塔塔门禁目录

`.github/` 仅保留 `workflows/` 与 `tatagate/` 两个目录。`workflows/` 持有本仓自动化；`tatagate/` 仅保留 `tatagate.json` 与 `tatagate.mjs`。前者登记本仓只读检查的身份与来源清单，后者只读取并核对本仓源码，不拥有资源准备、测试执行、产物生成或写入回执。


## GitHub塔塔门禁与同类记录清理

本仓保留自己的.github/tatagate门禁实现和合同。main的push只触发本仓.github/workflows/tatagate.yml，gate与cleanup在这一个文件内执行；检出准确GITHUB_SHA并验证本仓GitHub事件、main引用和HTTPS origin，门禁继续执行本仓现有检查。gate成功时删除本仓该门禁旧成功Run；gate失败时删除旧失败Run；另一类最近记录和活动Run保留。清理前重新验真Run、Attempt和结论，删除后回查；清理错误如实记录并由后续运行补清，不影响gate检查结论。塔塔控制台通过塔塔鹿鹿的一次生物识别保存、推送本仓，并按准确SHA与Run ID追踪独立门禁任务；门禁结果不影响已确认的推送。

本仓 GitHub 门禁接受 actions/checkout 的准确 HTTPS origin（同一仓库地址有或没有 `.git` 后缀），仓库、事件、提交和工作流身份仍逐项校验。
