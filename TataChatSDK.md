# TataChatSDK 技术文档

## 当前工作目录归属（第8步，2026-10-06）

本产品全部测试、编译临时数据和产物归 `/Users/rhett/tatachatsdk/target`。单平台不重复产品名或平台层，按build、ci、release、publish、test、tmp隔离。独立入口与控制台调用消费同一产品流程；控制台仅创建任务、调用与跟踪，不准备产品专用版本、依赖或步骤。下载半包、工具编译候选、工程视图、Runner步骤临时状态和测试夹具均属于当前产品工作区；永久工具与依赖原件继续归原件库。整个根target不进入Git、源码快照、程序摘要或打包输入。准确流程短锁、活跃任务保护、成功产物保护和原清理规则继续适用。

第8、9步完成目录与路径实现、根文档迁移及测试源码维护，未运行测试、门禁、编译或安装。本文唯一原件位于/Users/rhett/tatachatsdk/TataChatSDK.md；产品接口及流程直接以本仓实际代码和声明为准，业务字典库与其检查已撤销，不另建登记副本。历史验收事实不表示本轮改造已经通过验收，统一测试在第10步进行。根技术文档由本仓门禁按原文、JSON解码值及既有补丁快照扫描机密，仅报告路径；文档迁出不减少资料安全检查。


## 聊天功能的唯一产品归属

**聊天客户端的逻辑功能只能在 TataChatSDK 中实现；聊天服务端的逻辑功能只能在 TataChatServer 中实现。公民、途遇及其他产品只依赖使用。**

TataChatSDK 是聊天客户端逻辑功能的唯一实现产品；所有消费产品需要的聊天能力与修复都必须在本产品实现，通过公开接口供宿主依赖使用。

- 消息、会话、群组、加密、协议、传输、同步、重试、聊天存储、附件、通话及聊天界面行为，按客户端与服务端职责分别归 TataChatSDK 和 TataChatServer；新增功能、缺陷修复和平台差异也必须在所属塔塔聊天产品内完成。
- 消费产品只提供产品入口、身份与业务权益结果、服务地址及授权、主题和公开接口要求的平台配置；只通过公开接口接入，禁止复制、重写、包装成另一套聊天内核或维护产品专属聊天实现。CitizenServe、TuyuServe 的产品身份与权益授权不包含聊天数据面的实现职责。
- 宿主源码与锁文件固定消费真实已保存Git提交；禁止改用邻仓工作树或改写依赖缓存。正式分发依赖塔塔聊天Release；第三方市场分发使用公开市场版本。依赖使用不以公开市场发布为前置条件。

本产品为单平台，受控缓存固定为 `tatachatsdk/target/<build|ci|release|publish>/`，不增加平台层、`runs/` 或 `start/`。SDK 本机编译中间物与日志只进入所属产品target内的当前工作目录；依赖原件和工具原件仍分别只属于 `rely/` 与 `tools/shared/`。

当前依赖边界：TataChatSDK 的锁文件和产品脚本自行决定依赖、版本、来源及工具。塔塔控制台不扫描、不预审、不替产品选择依赖；产品可按需使用唯一 `rely/` 离线原件服务。

塔塔工具库仅保存控制台自身维护的工具，不是 TataChatSDK 的版本许可名单，也不能阻塞 SDK 的 Build、CI 或 Release。

NDK、Rust、Java、Gradle 与 Android SDK 均由 TataChatSDK 产品脚本自行选择和校验。本机 Worker 不调用工具准备器、不注入固定路径，也不以受控登记状态阻塞产品入口。

协议生成工具由tatachatsdk/scripts/dependencies.json唯一声明：四端protoc固定官方35.0，Dart插件固定pub.dev官方protoc_plugin25.0.0。准备器只在调用方源码外目录验证官方归档和设置隔离PUB_CACHE；TATACHATSDK_PROTOCOL_OFFLINE=1仅消费既有普通且摘要一致的原件。固定消费者声明protoc_plugin25.0.0，使用pub get并以--enforce-lockfile回读，离线模式两次均加--offline；核对实际package_config中的插件来源与官方归档全部文件，再由dart compile exe显式读取该配置，产出当前宿主官方插件可执行文件。禁止global activate、Dart包装器、系统同名工具、版本替换及用户全局缓存。非法开关、缺失、损坏、链接或目录归档立即失败，保留既有输入与生成输出。调用方事先交付锁定Pub闭包；准备与官方插件编译仍须具体授权。generate-protocol.sh继续使用两项验真的绝对工具路径，五份proto和十五份生成物保持唯一真源合同。

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
- TataChatServer 地址、短期授权及操作系统推送能力的公开接口适配；聊天认证消费、连接、传输与唤醒后的同步逻辑由 TataChatSDK 实现。
- 产品主题、品牌文案和平台权限配置。
- 业务专属身份、发送授权、支付、位置和转账。

## 3. 当前源码结构

- tatachatsdk/lib/tatachat_sdk.dart：公开入口。
- tatachatsdk/lib/src/attachment：附件密文、分块和文件库。
- tatachatsdk/lib/src/call：私聊通话状态和客户端边界。
- tatachatsdk/lib/src/core：通用消息、内容、会话与范围模型。
- tatachatsdk/lib/src/group：群聊模型与 OpenMLS 群流程。
- tatachatsdk/lib/src/mls：OpenMLS 会话、状态库和原生边界。
- tatachatsdk/lib/src/protocol：Protobuf 生成代码与严格编解码。
- tatachatsdk/lib/src/runtime：唯一运行编排、队列、同步和账户生命周期。
- tatachatsdk/lib/src/storage：唯一 Isar、系统保护记录、索引和公开绑定围栏。
- tatachatsdk/lib/src/ui：通用聊天界面。
- tatachatsdk/android、ios：SDK自己的Flutter平台插件与iOS集成资源；宿主不实现通用聊天媒体能力。
- tatachatsdk/native、tatachat_sdk.h、proto、scripts、test：独立原生、协议、构建与测试。

## 4. 运行时合同

ChatRuntimeCore 是唯一通用运行时。它只依赖 ChatRuntimeHost、ChatServiceTransport、ChatMediaLimitPolicy 和平台能力回调。

ChatRuntimeAccount 只携带通用字段。运行时不得出现宿主身份格式、授权等级、品牌名称或链类型。

账户上下文失效只清聊天上下文和聊天服务会话。宿主身份缓存由宿主业务流程自行管理，TataChatSDK 不得越权失效。

### 通用安装器与 SDK 接入边界（2026-09-03）

TataChatServer 的 `installer` 组件生成接入实例的 Cloudflare 或 LinuxARM 安装计划，
TataChatSDK 不依赖该组件，不读取 Workers、D1、R2、数据库或服务端推送凭据。
通用 SDK 的测试和正式包生成不要求任何接入产品的生产配置；具体实例安装时才检查其配置。
这不改变 SDK 的 HTTPS/WSS 限制、短期凭证使用方式、OpenMLS 或设备隔离校验。

公开入口 `ChatSdk` 直接继承唯一 `ChatRuntimeCore`，只接收同一 `ChatRuntimeHost` 与运行依赖；
`start()` 实际调用实时同步并复用已有重连、邮箱和待发队列。重复或并发启动只登记一次；
`isRunning` 表示同步生命周期已启动，不保证网络持续在线。服务地址和短期凭证统一使用
`TataChatServerAccess`，从 HTTPS 根派生 WSS，不再提供独立身份、权限或双地址配置入口。

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

## 12. TataConsole

TataChatSDK 在 TataConsole 中是独立产品，拥有自己的编译、CI、Release 和用户显式发布动作。
TataChatSDK 是单一 `sdk` 平台，本机 Build 只需完成产品编译；它不是 macOS App，因此不进入 `target/`。本次任务日志和中间物只在 `tatachatsdk/target/`。

Flutter、Dart 及其来源由 TataChatSDK 产品 Action 决定。产品可以主动读取塔塔工具服务，但 Worker 不在 Pub 或 Build 前验真、固定或拒绝其它正常产品入口。

正式 Release 资产验证使用该任务自己创建的临时目录，退出即删除；不再使用固定 `.verify`、
`.owner` 或占有记录。验证目录不写编译日志或成功产物，也不影响并行任务。

产品流程直接读取真实产品源码；编译输出使用 Worker 提供的缓存路径，不复制源码，也不要求控制台生成 Flutter 投影。产品自行决定 Pub、分析、测试和原生编译步骤。

本技术文档只记录代码与验证真相，不把尚未执行的 CI、Release、发布或部署写成完成。

## 13. 2026-08-31 第 3 步完成事实

- 通用运行时、ChatStore、ChatIsar、模型和 Isar 启动器已归属 TataChatSDK。
- 宿主应用不再保存这些通用实现。
- 数据库名和文件域已统一为本文件第 6 节所列唯一值。
- 运行时账户失效不再越权失效宿主身份缓存。
- TataChatSDK 代码、测试、原生目录和头文件的产品概念与外部原生耦合扫描为零。
- TataChatSDK 静态分析为零问题。
- TataChatSDK Flutter 测试 149 项通过；6 项依赖独立原生宿主库的测试明确跳过。
- 本步骤未执行 CI、Release、发布、部署或原生构建。

## 2026-08-31 第 4 步：唯一 TataChatServer 运行链路

- TataChatSDK 只保留一个具体运行传输 `内部 ChatServerConnection`。宿主只通过 `requestTataChatServerAccess` 提供服务地址、短期授权与到期时间；TataChatSDK 把授权作为不透明凭证直接交给 TataChatServer，不解析宿主身份、产品权益或授权载荷。
- 控制与小型密文消息只走 `wss://<chat-server>/realtime`，子协议固定为 `tatachatserver`，帧固定为二进制 Protobuf `ChatFrame`；单连接同一时刻只允许一个命令等待响应。
- 附件密文固定按 4 MiB 分块走 `https://<chat-server>/attachments/{attachment_id}/chunks/{chunk_index}`，上传、下载均校验长度、分块 SHA-256 和整附件 SHA-256；附件失败不关闭 WSS，也不阻塞文字消息。
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

## 15. 2026-08-31 第 6 步：公开包身份与测试归属

- TataChatSDK 产品名保持不变，Dart 公开包唯一名称固定为 `tatachat_sdk`；原生库、Pod 和 C ABI 继续使用 `tatachat_sdk` 与 `tatachat_sdk_*`，二者职责不同，不建立别名包或第二套实现。
- 本机开发、CI及Release：CitizenApp原始声明与锁统一到https://github.com/tuyutata/tatachatsdk.git，根路径.，准确提交6ea733efc14950616e116b2ca7ebffe2ce2f9a6e；工程准备器只消费本轮锁定Git原件，不编译邻仓。
- 第一方正式 Release：CitizenApp 使用准确的 `tatachatsdk-sdk-v<software_version>` GitHub Release Tag 与仓库内 `tatachatsdk` 子路径，禁止依赖浮动分支、伪造 Tag 或提交。消费 SDK 的正式 Release 不以 SDK 的 Publish 或公开市场上架为前置条件。
- 第三方使用：通过发布到公开市场 pub.dev 的 `tatachat_sdk` 版本接入。公开市场 Publish 是独立动作，不得因第一方消费 Release 而增设公开下载入口、分发服务或市场发布步骤。
- 正式 TataChatSDK 归档必须包含 CHANGELOG、公开许可证和贴纸资源，Release manifest 的 `package_name` 固定为 `tatachat_sdk`。
- TataChatSDK 自身目录禁止出现宿主产品身份、产品权益、链或品牌概念；具体第一方产品依赖顺序只记录在对应产品技术文档。
- TataChatSDK、TataChatServer 和各宿主测试只验证自身公开合同，不读取另一个聊天产品的实现源码。
- 第 6 步隔离验证完成：Flutter 静态分析 0 问题，Flutter 测试 156 项通过、6 项因未构建独立原生宿主库而明确跳过，Release 脚本测试 7 项通过，pub.dev 发布包 dry-run 0 警告；未执行 CI、Release、发布或部署。

## 16. 塔塔控制台手动 pub.dev 发布

- 成功 Release 只创建 `tatachatsdk:sdk` 待发布目标，不自动上传；只有用户点击“发布·SDK”并完成
  生产授权后，才允许发布 `tatachat_sdk`。
- 本机发布器只下载准确正式 Release 的唯一 `tatachatsdk.tgz`，先校验 GitHub Asset digest 与
  Artifact Attestation，再安全解包并验证内部 `release-manifest.json`、`SHA256SUMS`、包名、版本、Tag、
  源码 SHA 和完整文件闭集。
- 上传前查询 pub.dev 官方版本接口并执行 dry-run；扫码后才使用受保护的
  `pubdev:SERVICE_ACCOUNT_KEY` 换取短期 ID Token，在一次性 `PUB_CACHE` 中执行
  `dart pub publish --force`，随后回读官方接口闭合结果。
- TataChatSDK顶层Workflow 不增加发布文件，也不执行 `dart pub publish`；Release 与 Publish 始终是
  两个独立流程。


## 17. 2026-09-01 TATA 产品归属

- TataChatSDK完整源码由/Users/rhett/tatachatsdk和公开仓tuyutata/tatachatsdk持有；实际接口归本仓代码，技术文档唯一位于本仓根TataChatSDK.md。
- 唯一产品 ID 为 `tatachatsdk`，唯一 Dart 包名为 `tatachat_sdk`，唯一受控路由前缀为 `tatachatsdk.sdk`。
- Rust package/library、C ABI、Pod、Framework 与三端原生产物统一使用 `tatachat_sdk_native`、`tatachat_sdk`、`tatachat_sdk_*` 与 `TataChatSDK`。
- 第一方宿主本机、CI、Release统一锁定Git提交6ea733efc14950616e116b2ca7ebffe2ce2f9a6e，路径为根(.)；第三方使用公开包。
- TataConsole 的产品登记、产品路由分发、依赖清单、路由、软件记录、发布资产均按 TataChatSDK 独立产品登记。
- TataChatServer 已作为 `tuyutata/tatachatserver` 独立产品接入受控流程；TataChatSDK 与它只共享公开合同，不读取对方实现源码。

## 18. TataChatSDK 受控流程合同

- TataChatSDK 的 CI、Release 分别使用 `tatachatsdk.sdk.ci` 与 `tatachatsdk.sdk.release`，由本产品独立Workflow进入本仓scripts。
- CI 只恢复同产品、SDK 平台和工具链身份最近一次成功缓存；成功与失败各保留一个终态槽，正式 Release 固定全量构建。
- 下载并验真的依赖原件按内容摘要唯一保存在全局`tatatest/rely/objects/`，索引不记录产品归属；本轮依赖下载暂存、展开与编译中间物全部进入准确`tatachatsdk/target/<build|ci|release>/`流程目录，并由下一同身份任务首步完整清空。单包事务只处理正式成功产物，塔塔缓存库不保存第二份依赖原件或正式产物。
- TataChatSDK Release 属于证明型矩阵，TataChatSDKWorkflow 仅为该作业授予来源证明所需权限；发布仍只由用户点击塔塔控制台的 SDK 发布按钮执行。

## 会话 UI 运行控制器（2026-09-01）

- `ChatConversationController` 是单会话通用 UI 状态真源，统一持有本地快照、完整性提示、媒体缓存路径、乐观气泡、发送忙碌态、已读提交、WSS 通知、轮询降级和前后台生命周期。
- `ChatConversationListController` 直接持有同一 `ChatSdk`，是会话列表通用协调真源，统一保证首次加载单飞、待发重试、同一账户只建立一个 WSS 订阅，并在实时连接不可用时执行有限轮询。
- 完整页面在 SDK 内部把控制器接到 `ChatSdk`；宿主只提供用户键、账户键和产品宿主合同。SDK 不包含具体产品的 CID 格式、会员状态、钱包、资料、主题或推送平台配置。
- 页面销毁、切换后台或离开列表时必须由控制器停止计时器和实时订阅；宿主页面禁止再实现平行的轮询或生命周期状态机。

## 第 5 步：客户端合同验收（2026-09-02）

- TataChatSDK 是唯一通用聊天客户端实现，宿主只能通过产品适配器注入短期 TataChatServer 授权。
- 所有普通聊天消息统一使用 OpenMLS；文字、表情、贴纸与后续媒体消息不得建立第二套传输或明文旁路。
- 发件密文必须同时绑定消息编号、发送用户、发送设备、接收用户和接收设备；任一不一致在发网前失败。
- 收件邮箱必须再次校验接收用户和接收设备，跨账户或跨设备响应以 `mailbox_identity_invalid` 失败。
- 服务端消息只有在 OpenMLS 验密和本机持久化均成功后才进入 ACK 集合；失败密文保留到后续重试或七天到期。
- 推送只作为无正文唤醒信号，不作为消息载体。

## TataChatSDK 仓库身份（2026-09-02）

- TataChatSDK的源码仓库为`tuyutata/tatachatsdk`；任务身份统一为tatachatsdk.<platform>.<flow>，准确仓库操作由tuyutata组织App逐用途、单仓签发令牌。
- 仓库身份不得由模块或产品名称推测，也不得回落为 GMB；任务标题固定使用“塔塔聊天SDK”。

## 三端原生候选合同（2026-09-02）

- 产品编译器 `tatachatsdk/scripts/build-native.sh` 分离 `host`、`android`、`ios`、`macos` 四种模式；`host` 只生成本机调试库，`macos` 固定生成 ARM64 正式候选。Apple 链接参数只写入目标平台专属 Rust flags，禁止污染宿主 proc-macro。
- Rust 1.97.1 的 Release 宿主 proc-macro 单独固定为非优化、非裁剪配置，避免生成 4 字节错位而无法加载的 Mach-O；三端产品目标仍是完整优化的 Release 构建。
- 三端候选唯一闭集为 Android `libtatachat_sdk.so`、iOS `TataChatSDK.xcframework`、macOS `libtatachat_sdk.dylib`；Rust crate 不生成也不接受 iOS 静态 `.a`。
- 本机 Build 与 GitHub CI 分别独立调用产品编译器。两者只共享编译实现和产物合同；本机 Build 不发起、不等待、不下载 CI，CI 也不调用本机 Build。
- Release 只下载用户所选成功 CI 的三端候选，逐项验证来源 SHA 和 XCFramework 必需文件后，再生成可复核的 `tatachatsdk.tgz`、manifest 与校验和。


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
### Build与Start物理归属（2026-09-12）

本产品Build、CI和Release唯一实现位于产品scripts目录；TataConsole只按固定身份调用。Start由TataConsole启动产物库中的macOS成功产物，产品不实现Start。

- tatachatsdk：
  - `tatachatsdk.sdk.build` → `tataconsole/console/tatachatsdk/build.sh`

## CI与Release入口归属

本产品CI与Release由所属仓当前`scripts/flows.json`的remote_routes及各平台Workflow声明定位，完整执行入口为本仓`scripts/flow.mjs`。控制台读取当前声明、创建原有真实任务、获取准确仓权限并跟踪原Run；旧控制台CI/Release Shell与Swift执行文件已删除，不作为入口。

## 独立 GitHub CI 与 Release 工作流

本产品每个实际产品、平台、流程身份使用下列独立文件，主 Job 为 `flow`；CI 验证源码，Release 生成正式产物，发布由塔塔控制台的独立 Publish 流程负责。

- `.github/workflows/tatachatsdk-sdk-ci.yml`
- `.github/workflows/tatachatsdk-sdk-release.yml`


## 扁平源码与Flutter平台布局

Android唯一Java插件和Manifest直接位于android/，包名仍为chat.tata.sdk；公共原生头文件为根层tatachat_sdk.h。群界面位于lib/src/ui/group_views.dart，单文件测试归并到test/，不保留旧路径。

scripts/release.mjs公开createFlutterSourceView、assertFlutterSourceView及同名职责的flutter-source-view、verify-flutter-source-view命令。调用方提供互不包含的规范绝对源码根和输出根；SDK先完整核对来源，再在不存在的本轮输出目录装配Flutter标准Java包路径和Manifest。源文件只建立链接，Pub声明与锁文件使用独立普通文件，生成目录及旧Framework排除。复用前核对平台入口来源和Pub内容，拒绝链接目录、来源漂移、重复入口及旧工程叠加。Gradle继续从标准布局读取平台输入，宿主只调用接口，不复制SDK包路径规则。

## 独立公开仓库与源码根

唯一源码根为 `/Users/rhett/tatachatsdk`，唯一公开仓库为 `tuyutata/tatachatsdk`。仓根直接承载 SDK；CI 与 Release 使用 `tatachatsdk.tatachatsdk.sdk.ci`、`tatachatsdk.tatachatsdk.sdk.release`，只执行本仓 `scripts`。依赖合同中的 Dart 源根为 `.`，Rust 项目为 `native`；工具版本、Dart 包名、C ABI、Android/iOS/macOS 候选及一个 SDK 包的边界保持原声明。

CI 在源码外临时目录复制完整产品根并排除 Git 元数据，不把 `.git` 带入编译工程。正式包继续携带一个 `README.md`，其来源、软件版本与实际提交说明由包构建器只在临时包根生成并纳入 manifest 和 SHA256SUMS；源码不新增第二份技术文档。唯一技术文档仍由本文件承载。

初始保存通过控制台现有 `test/tatachatsdk/save.sh` 与 `saveRepositories(selection=tatachatsdk)`，只创建无父 main 提交；初始源码提交与正式 Release 候选是不同事实，不得把保存冒充测试、正式签名或发布完成。
## 完整产品组织与执行合同

所有者：`tatachatsdk`，正式源码根 `/Users/rhett/tatachatsdk`；本说明属于该完整产品。组件不会拆成独立仓库或目录产品。所有执行身份统一为 `产品.平台.流程`，单平台仅在控制台显示和物理目录中省略平台层。

真实平台目标：`sdk`。

推送门禁唯一源码位于 `/Users/rhett/tatachatsdk/.github/tatagate/`，GitHub入口 `/Users/rhett/tatachatsdk/.github/workflows/tatagate.yml`。控制台先从本仓已保存提交执行这份门禁，通过后推送准确SHA；GitHub main push再执行同一提交的门禁，控制台核对所属仓、Workflow、main、SHA、Run和attempt，只有success并再次回查main一致才完成推送。失败、取消、超时或身份漂移均不得显示成功，不自动重试或派发CI/Release。

技术文档由所属完整产品仓根唯一持有；私有规则和任务库由控制台私仓持有，公开产品不读取它们。公开门禁不依赖私仓资料、安装包源码、其它本机产品或个人账号；必要链真源先锁定公开main的实际SHA后只读该SHA。本机开发跨产品验收仍比较三仓已保存快照与各端真实镜像。


### 门禁与开发审查职责

准确中文注释按开发阶段逐项复核，不以保留源码每文件包含汉字作为仓库门禁的开发凭证。初始完整内容、生成文件和上游原件保持原文；真实第一方临时注释、机密、源码输出、Workflow、依赖和适用测试仍由本仓同提交门禁验真。公民门禁只把scripts中的Node命令行结果报告识别为CLI输出；本仓实际执行测试的准确协议拒绝断言不属于新运行协议，字符串、注释、模板和未登记测试中的同文不豁免。保存及推送仍逐仓独立授权，并以本机门禁和同SHA的GitHub门禁双成功为唯一终态。

### 仓库合同与平台验收归属

CI与Release的Job合同断言统一按tatachatsdk.sdk.ci和tatachatsdk.sdk.release三维身份执行，禁止重复产品维度。

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

本产品的scripts/flows.json声明自身平台、准确工具版本、原始锁以及既有CI/Release入口；scripts/build.mjs独立实现requirements、prepare、build三个阶段，拥有工程准备、编译命令、候选验真和失败条件。产品只消费调用方交付的公开资源回执，按本仓原始锁取得依赖，所有生成状态进入规范源码外工作目录。平台或资源身份不符、版本错误、缺锁、链接越界、归档摘要错误、旧工程复用或编译器失败均立即失败。

本产品平台闭集为`sdk`。调用格式为`node scripts/build.mjs <requirements|prepare|build> <platform> --work <绝对工作目录>`；requirements只读并输出唯一JSON，prepare/build从标准输入读取schema=1的资源回执。调用方交付准确工具执行器、锁定依赖目录、Git来源和归档后先prepare，再读取展开来源新增的需求，完整交付后执行build。准备、展开和编译属于同一调用工作根，各平台互不共享可写状态。独立调用方按本仓声明准备资源即可运行，无需读取其他产品工作树或私有资料。

Git依赖只接受本仓声明与锁一致的HTTPS地址及40位固定提交；原生归档只接受本产品锁定坐标及完整SHA-256。工程副本排除旧生成物，内部文件链接重映射到同轮副本，外部链接与已有工程拒绝。原始依赖缓存必须显式交付，不能落入用户默认缓存；离线编译禁止隐式取得缺失资源。已有CI/Release Workflow仍各自调用本仓scripts，不受本机可视化入口是否存在影响。入口回归由本仓`scripts/build.test.mjs`负责，适配与资源服务的验证不替代产品编译和真实候选验收。


## 2026-10-06 产品自主资源阶段（第2步）

本仓`scripts/resources.mjs`拥有工具准确来源/版本/配方、递归锁解析、缺失获取、验真、复用和本轮依赖准备；`scripts/build.mjs resources <platform> --work <绝对外部工作根>`调用同一实现，独立入口为`resources.mjs <platform> --work <工作根> [--offline]`。前者从stdin读取公开身份回执；后者允许空请求。最小宿主必须使用本仓声明的官方Node25.2.1绝对入口，本机配方限定macOS ARM；资源阶段回读官方发行归档与运行Node字节，不能从PATH取同名程序。工作根预先存在、位于源码外且不经过链接。

可选`PRODUCT_TOOL_ROOT`只供读取工具原件，`PRODUCT_DEPENDENCY_ROOT`只供读取依赖原件；产品不读取供给者的版本决策或私有任务变量。独立缺省原件库为源码外`~/.local/share/product-resources`，本轮可写状态仅在work。GNU Bash/grep/sed纳入自身需求；发行件旧Shell仅用于声明中的首次GNU构建，不进入正式PATH。下载/源码工具编译不持全局锁，最终不可变对象提交使用短锁，取消传递到工具进程组。错误摘要、损坏、未锁来源、路径越界和显式离线缺失失败并保留可疑原件。

Pub/npm/Cargo按原始锁准备；Git按固定HTTPS提交检出，Git Cargo目录源展开workspace继承并锁定相对包版本；CocoaPods按准确锁摘要恢复验真快照，缺失spec校验规范摘要，未锁源码来源拒绝取得。Android固定包与修订归产品；额外平台仅消费官方固定发行来源与发行树摘要，不借宿主历史SDK目录。Maven供给只读验真后复制到独占Gradle缓存，由产品准备现有配置，消费仍离线；全库坐标导入与旧目录清理留到第5步。

`PRODUCT_WORK_DIR`、`PRODUCT_BASH_BIN`、`PRODUCT_RSYNC_BIN`及`PRODUCT_SOURCE_DIR`是公开工作/工具/工程入口；Flutter修订不读取调用方私有变量，也不回退系统rsync。旧Flutter补丁对象与当前配方不符时拒绝复用，真实替换须按准确资源操作另行授权。本步不改变编译、签名、安装及回读顺序，不修改产品UI，也未执行真实工具下载/安装。受控资源测试不能代替官方首次取得、正式编译或最终真实运行验收；第4至7步仍待逐步确认实施。

资源原件按完整内容验真后整体提交：Git bundle与固定来源/摘要回执处于同一个不可变对象，不暴露中间状态；可选依赖供给读取`objects/<SHA256>.blob`。锁解析器、源码工具依赖与官方有序补丁也从同一产品原件存储复用。Pod spec每次按锁中的规范checksum回验，Git tag只核对发行声明并消费本产品预锁提交；HTTP发行件消费固定SHA256，首次源码准备命令来自该已验真spec并由GNU Bash执行。spec、准备后源码与文件清单整体提交，再复制到本轮缓存；供给索引不决定产品版本。正式PATH排除旧POSIX Shell，`sh`对应已验真的GNU Bash。

独立缺省资源目录内`tools`保存工具发行件及工具编译输入，`rely`保存产品依赖的归档、Git和Pod原件；工作区只承载本轮可写视图。根据用户最新要求，分步骤先完成实现与用例，整项解耦任务完成后统一测试；本步实施记录不等于真实工具首次取得、完整Build或安装验收通过。


### 第3步：产品完整Build入口（2026-10-06）

本产品的正式完整入口为已锁定Node的绝对路径调用`/Users/rhett/tatachatsdk/scripts/build.mjs execute <platform> --work <已存在绝对工作根>`，可选`--offline`。输入stdin可为空；调用方可传schema/product_id/platform/work及真实run_id/program_digest，禁止私有变量或执行命令。入口内部完成需求→资源→准备→再次需求/资源闭包→编译→适用签名/安装/回读；独立与控制台调用同一实现。最小引导Node只启动本产品的资源引导器，产品按自己的官方Node声明验真、准备并重入，控制台运行Node不决定产品Node版本。

标准输出只有唯一有界JSON：schema、product_id、platform、work、completion、files及可选真实run_id。completion沿用固定平台的device-install/macos-artifact/compile-only；files按本产品flows.json登记路径和SHA256。编译日志使用stderr进入现有任务日志，不新增资源任务或任务状态。完整结果只在各阶段成功、源码/锁不漂移、工具进程确认退出后落入本轮build-result.json；同根并发或复用旧结果拒绝，取消/失联/错误身份/损坏候选不得成功。

控制台每次Build直接读取本产品当前flows.json入口，调用一次execute；控制台只跟踪真实任务、核验公开结果和保存产物，不解释产品工具、依赖、编译参数或设备规则。当前控制台静态菜单、其它产品流程/安装器与程序摘要的历史耦合仍归第4步解除，本步不能当作整项解耦已完成。

本步同步完整入口、失败/取消/并发、结果/路径/摘要及适用移动端用例，但未运行测试、语法检查、编译、签名、安装或工具下载/替换；全部实现步骤完成后统一验收。源码交付与用例存在不代表真实Build已经通过。


### 第4步实施中：远端路由当前声明

CI/Release的规范身份、标题、版本前缀和正式版本记录标志已迁入所属仓现有scripts/flows.json的remote_routes。调用方按固定已接入动作重读当前声明；原生授权与流程查询不再使用编译期产品路由常量。产品声明只提供数据，不授予凭据、扩大平台矩阵或新增按钮。损坏、重复、越仓、字段越界及超限拒绝。

本次同步路线读取、热更新和失败边界用例，未运行测试、语法检查、编译、签名、安装或下载。第4步仍在开发中：Publish执行器、聊天安装器、Start、固定菜单声明与完整程序摘要的其余实际耦合尚未解除，不能报告该步或整项任务完成。

### 产品远端完整入口

本仓`scripts/flows.json`的`flow_entry`定位公开`scripts/flow.mjs`。`run ci <platform>`和`run release <platform>`分别执行同一产品流程，当前读取本仓Workflow与路由；Release的`version_source`声明准确版本文件类型和相对路径。成功CI选择、同源候选复用、版本递增、正式Release验真与旧Run/Artifact清理均由本产品入口完成。独立执行只需等价的本仓短期GitHub权限；没有宿主控制管道时入口自行跟踪Run，不依赖其它产品程序。

可选`PRODUCT_CONTROL_FD=3`只接受当前Run绑定确认、候选持久化确认和二值远端终态；令牌仅进入HTTPS请求头，未知身份、越仓、无成功CI、候选错源、控制帧错误、超时或取消均失败。宿主重启后的`recover`使用同一公开入口核验原Run、原候选并清理，不重新派发。公开控制协议不携带私有调用方变量，现有授权及用户操作顺序保持。源码、声明或Workflow在本次流程期间变化将拒绝继续。

相关正常、失败、身份、版本来源、独立远端跟踪、候选重试和真实控制管道边界用例位于本仓`scripts/flow.test.mjs`；当前只完善源码，尚未运行用例或远端操作。


### 产品软件记录与正式版本恢复

本仓公开`scripts/flow.mjs records`使用准确同仓短期GitHub权限，重读本仓当前路由，复用远端流程同一Run保留器并确认实际删除，再读取各平台最新正式版本。来源合同归本仓release.record_source：按实际产品选择Tag、单包正文或正式元数据资产验真，标题、版本、源码与适用不可变标志不能由调用方推测。准确元数据资产仅经官方HTTPS地址读取，跨主机不转发仓库令牌。正式资产和Tag不会在记录刷新中删除。公开结果仍是records/removed_run_ids，原记录页行为保持。

`recover`不重新派发；重新核验原候选、成功CI、原Run终态、正式资产来源与Tag，输出formal_release/removed_run_ids。控制调用方仅绑定原任务身份、原候选和产品公开回执，更新现有持久发布目标；产品验真算法不再随调用方程序编译。相关正常、失败、错资产/正文/来源、重定向隔离、独立记录刷新和恢复用例源码归本仓flow.test.mjs。

资源工具取消、超时、输出超限和异常收尾均等待主进程与整个后代组退出；无法确认退出时保留工作根和候选，禁止删除输入或改为可写。真实取消退出顺序用例仅写入resources.test.mjs，尚未执行。


### 发布实现范围

本轮新增产品发布实现已撤销，发布功能由后续逐个产品重建。现有操作入口与界面保留，当前不提供已删除实现的执行保证；Build、CI、Release和Start继续按各自现有入口运行。


### 产品独立资源与唯一依赖供给

本产品的scripts/resources.mjs拥有资源解析、来源与摘要验证、缺件取得、可写视图和失败条件。PRODUCT_DEPENDENCY_ROOT是可选只读供给；没有供给时使用源码外的本产品原件存储，产品需求仍只由当前源码、声明和锁决定。依赖索引读取仅接受schema_version=2及packages、git_sources、pods，不恢复旧目录或整锁快照。

Maven的具体JAR、AAR、POM、module及分类器文件统一由packages的group:artifact、version、准确上游URL、SHA256和SRI定位objects中的原件。产品在本轮work/dependencies/maven按上游分区复制独占文件；不复制Gradle二进制元数据、锁和下载状态。产品生成本轮GRADLE_USER_HOME/init.d初始化脚本，只在自身已声明的同源仓库之前加入本轮原件视图，缺件仍按产品原仓库解析，明确离线则失败。Gradle解析、工程状态和后续编译都属于同一产品任务。

Pod由pods中的name、version、checksum匹配当前Podfile.lock；spec保存官方CDN地址和原件摘要，source保存官方podspec来源，files保存发布树相对路径、文件内容摘要与权限或安全内部链接。只物化本产品所需的单个发布坐标；其它Pod、整锁、平台或宿主变化不要求复制全树。产品仍按CocoaPods官方规范回验SPEC CHECKSUMS，再验证本产品预锁定Git提交或HTTP发行摘要与源码回执。可写缓存和工具VERSION仅在本轮work产生，不能写回共享原件。

错来源、摘要、重复同源内容、生成状态、硬链接、内部链接越界或循环、取消及任务副本漂移均据实失败。独立与控制台调用使用同一实现；控制台只提供可选原件并跟踪原有任务，UI、功能、按钮、平台与操作顺序保持。用例源码已同步，执行留待整项实现结束后的统一测试。


### 独立入口回归验真边界

资源回归使用自带固定提交、源码字节和spec的合成Pod，不借用产品真实Pod清单提供测试输入；无真实Pod需求的平台也验证来源、摘要、链接、循环、取消和物化失败。测试现场仍位于本产品target的准确平台，不写源码或其它产品目录。资源声明与生产依赖坐标不因测试夹具改变。

资源取消对同一真实进程组每轮只发送一次信号；组不存在或Windows时才发送给主进程。仍等待主进程和后代实际退出，8秒未退出才强杀，12秒仍未确认则保留现场并失败；取消不能成为成功。


### 门禁官方归档字段与平台命名边界（2026-10-07）

平台禁用值继续来自本仓既有门禁登记。仅scripts/resources.mjs的唯一规范toolDefinitions声明内、唯一Flutter工具的archive.url可以按对应数字版本核对官方稳定版macOS归档；source、root和executable必须匹配原有官方坐标。识别后仅从平台扫描输入移除该URL，原资源源码、工具版本、来源及依赖锁均不修改。重复声明、重复键、转义或不可解析字面量、错版本、错来源及错形字段不予豁免；其它工具、字段、源码、注释和目录中的旧平台标识继续拒绝。

既有门禁测试覆盖本仓真实资源声明、官方字段、伪造来源和字段、歧义字面量、额外源码、旧平台注释与目录；全部夹具只在本产品target真实平台测试目录生成，并在finally清理。工作树诊断与绑定已保存提交SHA的正式门禁分别记录，不能将缺少Git跟踪文件的工作树冒充正式通过。

当前完整门禁回归11/11通过，失败/取消/跳过/待办均0；本仓真实根技术文档、机密扫描及平台命名检查通过。完整资源源码和补丁边界、既有链接/临时目录/根文档夹具的失败已消除。测试及工作树检查不代替绑定已保存提交SHA的正式门禁，也不代替产品真实Build、签名安装及启动验收。本轮自有日志与夹具在结果记录后按原规则删除。


### 补丁原上下文与测试夹具边界（2026-10-07）

平台扫描只对scripts/resources.mjs中唯一规范flutterPatch JSON字面量执行原上下文识别：补丁登记字段严格为path、sha256、source；path为flutter.patch，source为Flutter官方固定40位提交，正文首行固定来源必须一致，全文SHA-256必须匹配本仓登记。仅当native_assets_host.dart准确文件、hunk及lipoDylibs邻接上下文唯一匹配时，从扫描副本移除那一行已核对的上游原注释。实际资源源码和补丁正文不修改；其它补丁行、源码、字段和目录继续完整扫描。错误来源、摘要、重复声明、非规范转义、上下文漂移和新增旧平台文字均不豁免，不跳过整段补丁。

既有门禁夹具以unlinkSync删除测试目录中的链接自身；测试临时目录仅调用本仓唯一testRoot，无旧API别名。机密扫描夹具生成本仓必需的合成根文档，原文档检查及拒绝断言保持。补丁正常、错源、错摘要、错形、重复、上下文外残留等边界同步在既有test.mjs，现场在本产品target内并由finally清理。补充实现后的统一门禁验收已通过，正式提交门禁及产品真实Build/启动验收仍待完成。


本产品scripts/build.mjs的模块初始化与CLI执行分离：私有异步runCLI承载原命令主体，仅在直接执行文件时启动，拒绝时输出错误并以退出码1失败。模块求值先完成，scripts/resources.mjs可反向导入同一checkWork、requirements和平台校验，不复制实现或增加启动入口；普通import不启动CLI。现有公开参数、JSON请求、--offline、锁定Node验真和必要重入、资源/准备/编译/适用签名安装回读步骤以及取消与结果合同保持。离线缺件和非法输入必须真实失败，禁止以未完成顶层await退出替代完整结果。对应真实CLI回归只在自有target测试现场替换资源供给边界，验证反向导入、参数与错误传播，不据此声称实际产品编译通过。


本产品scripts/resources.mjs的普通inventory清单保持独占文件要求；工具原件toolInventory复用同一扫描实现，只允许全部真实名称均位于同一规范payload内的硬链接组。扫描按dev/ino分组，实际名称数量必须与nlink闭合；工具普通文件以O_NOFOLLOW打开，打开及读取后复验身份、计数、权限和字节相关元数据，扫描结束再回读全部目录、文件及链接身份与规范目标。原件外额外名称、目录或链接越界、特殊项、读取期间替换/权限/内容变化均失败。清单仍逐路径保留原有path/sha256/executable或directory/target格式，继续由既有回执、准确官方归档/版本、配方和编译输入证明验真；regular与其它资源默认独占校验不放宽。不新增公开命令、参数、声明字段或原件登记，不改版本、锁、配方和工具原件，不以拆分内部链接、重新安装或下载解决验真。回归复制本仓完整实现到所属target测试现场，仅替换文件IO边界以确定性制造读取变化，并在夹具内暴露已有私有验真函数；纯合成对象覆盖正常、拒绝与回执漂移，不据此宣称真实工具或产品编译通过。


本产品资源验真将下载运输元数据与源码工具编译身份分开：仅在源码工具证明和本产品声明的比较副本中，验证并移除archive.mirrors与upstream_patches各项mirrors。镜像须为非空、无重复、无控制字符/空白、无账号/口令/片段的准确规范HTTPS地址数组；错误格式直接失败。官方来源URL、版本、归档字节摘要、kind/root/executable、补丁来源/摘要/顺序、前置与依赖闭包、其它位置同名字段及未知字段继续严格比较。Xcode/POSIX输入、recipe.source和source.archive/source.gem摘要、原回执清单及入口独占规则不变；比较不改写原证明、声明或回执，不改变原件/登记/配方/版本/锁和实际下载策略，不读取控制台登记作为产品版本或策略来源。既有回归使用完整本仓资源实现及纯合成物理证明，逐次重算清单，验证运输差异可复用与真正输入漂移必须失败；测试不启动工具或冒充真实编译交付。
