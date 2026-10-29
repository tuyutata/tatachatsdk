# 塔塔聊天 SDK

TataChatSDK独立拥有聊天客户端逻辑、原生引擎、公开接口、原锁及完整构建流程。聊天服务端归CitizenServe.tatachat。产品需求只在本文维护，全局规则以/Users/rhett/tataconsole/TATA.md为准。

## 编译与塔塔自动化

编译入口为scripts/build.mjs；工具及纯版本声明归scripts/config.mjs，独立构建测试归test/build.test.mjs；公开流程声明及实现归本仓scripts/config.mjs，控制台只调用声明和显示公开状态。SDK是唯一公共平台，Android、iOS、macOS只是内部编译目标；它们不产生独立版本或独立平台Artifact。

公开命令：node scripts/build.mjs test执行Rust测试、宿主库编译、Dart严格分析及全部Flutter真实测试；默认命令编译三端并交付完整SDK目录；归档、正式版本和网络请求由GitHub工作流的官方命令执行；native android/ios/macos只用于独立核验内部目标；protocol直接调用显式交付的官方protoc和Dart插件。编译命令输出JSON只包含本轮work和output目录，失败退出非零。不接受控制台任务宿主、资源回执、供给路径或旧固定现场协议。

工具版本唯一声明在config.mjs的tools：Node 25.2.1、Rust 1.97.1、Flutter 3.47.2、NDK 28.2.13676358、protoc 35.0、protoc_plugin 25.0.0。使用电脑现有正式工具及官方工具命令；CI按声明调用setup-node、rustup、官方Flutter Git仓库和sdkmanager，并明确交付声明的NDK绝对路径，避免运行机预设环境指向另一版本。Flutter首次启动先用普通版本命令完成官方初始化，再读取机器格式版本JSON，冷缓存与热缓存遵守相同版本核对。缺依赖按native/Cargo.lock、pubspec.lock正常下载，禁止升级锁定版本或依赖控制台工具库存。协议生成通过PROTOC与PROTOC_GEN_DART明确交付官方可执行文件，不执行全局激活，不自动改写源码生成物。

编译使用target/build/sdk-*，测试使用target/test/sdk-*，各轮独立；失败和测试结束后清理本轮目录，成功保留准确产物供消费方使用后清理。取消先终止本轮进程组，未确认退出时保留本轮现场与缓存锁，不清理活动进程的文件。源码根按脚本位置解析，GitHub使用checkout默认工作目录。target/cache/rust复用Cargo增量数据，target/cache/pub保存Pub下载，target/cache/flutter保存本产品锁定Flutter工具；缓存占用、不可写或目录异常时使用本轮独立Cargo和Pub目录，不等待其它任务。GitHub官方cache恢复和保存均限时并允许失败，缺缓存正常下载和构建；真实工具或构建失败仍使任务失败。

测试原生库必须是本轮目录内真实普通文件，通过TATACHATSDK_TEST_WORK_ROOT和TATACHATSDK_TEST_NATIVE_LIBRARY交付；只验证实际目录与文件边界，不再读取.active.json或PRODUCT_WORK_LEASE。Isar Core从本轮Pub原锁解析的package_config定位并复制到本轮目录，通过ISAR_CORE_LIB_PATH交付。每个数据库测试仍独占自己的临时数据库。

原生目标：Android aarch64-linux-android（API24，arm64-v8a）；iOS真机aarch64-apple-ios与模拟器aarch64-apple-ios-sim组成TataChatSDK.xcframework；macOS aarch64-apple-darwin。实际产物检查ELF/Mach-O架构、Mach-O目标平台和头文件中所有FFI导出，拒绝退役接口。正式SDK包包含原始Dart源码、Flutter插件、原生头文件与源码、三端二进制、Pub原锁和独立脚本；iOS Framework与Android jniLibs在交付包内按标准相对路径装配，正式源码不写入二进制。

真实公共布局接口createFlutterSourceView、assertFlutterSourceView和analysisOptionsBytes继续由SDK持有，供现有公民、途遇消费者调用。Android扁平源码仅在本轮工程映射到Flutter要求的src/main路径，分析配置直接生成正常YAML，不解析内嵌Shell或复制旧资源框架。

GitHub只有sdk.yml一个工作流、一个SDK执行Job：读取SDK公开声明核对版本→test/build.test.mjs代码回归→Rust/Dart真实测试→三端编译汇总→ditto与shasum生成归档清单→单一Artifact→gh原生命令生成正式Tag和Release、下载附件逐件cmp核对。编译脚本不包含GitHub API、Release/Tag、历史版本清理和内嵌测试。固定Workflow为塔塔聊天·SDK，所有逐次Job、Run、Artifact、Tag、Release均为塔塔聊天·SDK·vX.Y.Z。压缩包、JSON清单和SHA256文件使用相同前缀并保留扩展名；GitHub会规范化下载文件名，Release附件以官方label保留完整中文显示名，回读按唯一标签定位实际下载名并逐字节核对。

版本从最新成功Run读取并仅增加补丁号；失败不消耗候选版本，不以Release创建时间或运行次数推算。没有成功Run时以pubspec.yaml.version为首次候选；存在无法识别的成功Run时拒绝猜测。SDK同一时间只允许一个活动任务，重连仅核对原Run。新正式版本附件全部上传、回读并核对Run/SHA/摘要后才成功；失败候选只能在核对原失败Run后清理重试，禁止覆盖成功版本。


旧工具安装框架、磁盘映像、依赖供给回执、源码冻结副本、通用Build解释器、脚本文本断言及固定现场租约已删除，不保留旧接口别名或兼容执行分支。

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

- tatachatsdk/lib/tatachat_sdk.dart：lib根层唯一文件与SDK公开聚合入口。
- tatachatsdk/lib/attachment：附件密文、分块和文件库。
- tatachatsdk/lib/call：私聊通话状态机、会话、协调器、信令与客户端边界；状态和会话类型统一定义在coordinator.dart。
- tatachatsdk/lib/transport：WSS 控制面与同源 HTTPS 附件数据面。
- tatachatsdk/lib/core：通用消息、内容、会话与范围模型；basic_content.dart与media_content.dart分别拥有对应私聊入站消息类型。
- tatachatsdk/lib/group：群聊模型与 OpenMLS 群流程。
- tatachatsdk/lib/mls：OpenMLS 会话、状态库和原生边界。
- tatachatsdk/lib/protocol：Protobuf 生成代码与严格编解码。
- tatachatsdk/lib/runtime：唯一运行编排、队列、同步和账户生命周期。
- tatachatsdk/lib/storage：唯一 Isar、系统保护记录、索引和公开绑定围栏。
- tatachatsdk/lib/ui：通用聊天界面。
- tatachatsdk/android、ios：SDK自己的Flutter平台插件与iOS集成资源；宿主不实现通用聊天媒体能力。
- tatachatsdk/native、native/tatachat_sdk.h、lib/protocol、scripts、test：独立原生、协议、构建与测试。

lib根层只保留tatachat_sdk.dart一个公开聚合入口，直接导出各所属模块，不设置分散聚合文件或旧路径转发。私聊收发编排与ChatSdk生命周期归runtime/chat_runtime.dart及既有收发模块，内容模型与入站消息归core，语音/视频会话和状态归call/coordinator.dart。保留原公开类型名称、构造函数及行为；内部源码直接导入所属模块，消费者继续从唯一总入口取得SDK公开能力。


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

普通打开只使用当前数据库和附件目录，不导入、转换或删除旧格式。显式用户清理和全量擦除仅处理SDK准确拥有的对象，并保留生产者收口、跨isolate文件锁、关闭和删除回读；钱包存储不属于SDK删除范围。真实现存旧格式的升级处置须另行核实，不能借用户清理合同自动执行。

### MLS持久身份与原子收发（第1步）

SDK原生生成每个user_id每台设备的一份Ed25519 MLS签名身份。device_id为该公钥的无前缀十六进制公开值；身份读取只返回user_id、device_id、public_key。私钥不导出，应用认证仅开放下文的固定结构证明。公民宿主把binding.cidNumber映射为user_id；account_id与device_id分别保持各自职责。普通MLS使用不请求钱包派生或生物识别。

公开readLocalMlsIdentity入口根据宿主当前账户自动准备同一MLS身份，不连接服务、不查询权益、不请求钱包签名。prepareMlsStorage只交付保护目录；prepareIdentity在原生同一锁内完成合法空目录首次准备、未交付阶段续行或已有身份复用，不依赖本次mkdir结果。已提交身份缺失、损坏或所有者不符均失败，禁止替换。聊天就绪编排继续生成KeyPackage、连接和发布，并按实际key_package_ref确认原提交。

iOS使用ApplicationSupport/tatachat_sdk_mls/<UTF-8用户标识hex>，目录0700、文件0600、排除备份，秘密写入前设置并回读completeUntilFirstUserAuthentication。该保护在重启后首次解锁才允许访问，此后可支持锁屏后台处理；它属于系统文件保护，不宣称OpenMLS私钥硬件不可导出。保护语义以[Apple官方文档](https://developer.apple.com/documentation/foundation/urlfileprotection/completeuntilfirstuserauthentication)为准。Android使用应用凭据加密存储的noBackupFilesDir/tatachat_sdk_mls同一用户编码目录，必须确认用户已解锁，拒绝设备保护区域和符号链接，不创建KeyStore包装钥。各端普通MLS使用均不要求逐次生物识别。

state.bin为唯一现行快照：同一文件保存身份、OpenMLS MemoryStorage、早到密文及协议操作结果。state.lock独占锁覆盖读取、协议变更和提交；Android、iOS和macOS共用系统flock，文件描述符持有至事务退出并随关闭释放，只有Interrupted重试，其他错误失败关闭；不调用Android尚不支持的Rust File::lock，不以进程内互斥替代跨进程锁。验证须包含Android目标真实执行、不同描述符排他、释放后继续、失败后重试且身份与协议快照不变。合法空目录或仅空state.lock而无state.bin时自动准备；可验证的未交付阶段允许续行，committed缺文件则拒绝换钥。state.writing写入、文件同步、同目录rename及父目录同步构成提交。读取只采用已提交state.bin和系统保护，缺失或损坏时明确失败；read和sign_authentication动作不生成身份。

状态变更必须使用既有message_id，按动作种类与message_id保存精确请求和结果；同标识输入改变必须拒绝。发送状态和密文、原时间、原成员集合同时提交，重试返回原结果。接收状态与处理明文先提交，业务数据库成功后确认原生结果，再返回服务端ACK；确认后删除处理明文。stale只有精确请求存在已确认收据才允许ACK，验密失败不能伪装成重复。现有业务行的message_id存在不能代替原生精确请求复核。

pending_results无message_id时仅返回未确认结果，指定message_id时读取该操作仍保留的提交结果；未确认结果最多256项，满时明确阻止新操作且不得丢弃。确认收据从首次确认起保留七天。业务落库与原生确认不是跨库事务，由已提交结果重放及幂等业务写入补齐中断窗口。早到消息在现有队列重放时仍使用原消息message_id。

SDK用户清理和全量擦除的所有权与执行边界见本机存储章节；MLS持久身份不得因普通打开或schema不匹配被替换。

### 同CID通讯录MLS组

MlsContactSync 使用与聊天及普通认证相同的持久MLS身份，业务交换由宿主提供，仅接受已验证的HTTPS接口。它不依赖聊天权益或聊天连接，不增加私钥。Native add_members 核对实际 KeyPackage credential、叶子签名公钥与预期 user_id:device_id；remove_members 仅接受完整、无重复且存在的精确设备叶子，聊天上层按用户展开设备列表。

CitizenServe按当前MLS会话派生CID和设备，闭集动作publish/state/reserve/commit/ack。组版本CAS、operation_id幂等和原生精确请求/结果共同覆盖提交中断。实际应用消息发送者必须与队列公开发送设备一致；application只接受operation_id、owner_cid_number和规范payload_base64，32KiB业务载荷由SDK编码后封装。业务落库后才确认原生结果，再确认设备队列；已确认原生结果的队列重放只补ACK，不重复合并或消耗发送链。新设备只能经有效成员Welcome加入；全部MLS状态丢失无法用钱包恢复旧组。未完成预留操作必须由原设备恢复，不能通过重新建组跳过已推进的协议状态。

网络附件协议替换尚属第6步；本步源变更未经运行验证。全部七步源码、注释、测试源码及残留清理完成之后统一测试与两平台真实验收。

### 同一MLS身份的受限应用认证（第2步）

唯一宿主入口为ChatRuntimeCore.createMlsAuthenticationProof(MlsAuthenticationRequest)。请求只包含service_origin、challenge、expires_at_millis、method、request_target及正文body_hex；Dart模型接收并复制不可变bodyBytes，JSON编码由SDK产生。调用方不能提供用户、设备、密钥、签名标签或任意待签字节。当前user_id、account_id与binding_revision来自宿主账户，device_id与public_key来自已存在的MLS状态。公民宿主的user_id继续是CID，SDK仍使用中性字段。

底层MlsStateStore.signAuthentication复用tatachat_sdk_mls_identity_json的sign_authentication动作；prepare、read、sign_authentication各自严格限制字段，未知字段和动作直接拒绝。认证只加载已有身份，即使目录刚创建也不初始化。丢失快照、缺签名身份、损坏、保护不符或错误所有者均失败，错误不携带账户、挑战、正文或秘密。原生还检查签名身份算法并使用登记公钥本机验签，私有材料损坏但仍可解析时也不交付证明。认证不持久化证明，不修改MLS快照、处理结果、群epoch或ratchet，不需要生物识别。

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
`UIDocumentPickerViewController`；只允许一个单文件请求，取消返回空，选中内容按宿主传入的max_bytes上限流式复制到
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


## 16. pub.dev 发布边界

塔塔自动化生成唯一正式SDK ZIP、JSON清单和SHA256文件，附件挂载于同名正式Release和Tag。不会执行dart pub publish；pub.dev或其它应用市场提交属于后续发布，必须另行授权。

控制台发布动作必须交付已完成的正式资产或显式源码与三端原生资产路径；无产物参数的 local --run-id 入口已删除。Publish 不启动 Build，也不从未保存的工作树推断正式提交。


## 会话 UI 运行控制器（2026-09-01）

- `ChatConversationController` 是单会话通用 UI 状态真源，统一持有本地快照、完整性提示、媒体缓存路径、乐观气泡、发送忙碌态、已读提交、WSS 通知、轮询降级和前后台生命周期。
- `ChatConversationListController` 直接持有同一 `ChatSdk`，是会话列表通用协调真源，统一保证首次加载单飞、待发重试、同一账户只建立一个 WSS 订阅，并在实时连接不可用时执行有限轮询。
- 完整页面在 SDK 内部把控制器接到 `ChatSdk`；宿主只提供用户键、账户键和产品宿主合同。SDK 不包含具体产品的 CID 格式、会员状态、钱包、资料、主题或推送平台配置。
- 页面销毁、切换后台或离开列表时必须由控制器停止计时器和实时订阅；宿主页面禁止再实现平行的轮询或生命周期状态机。


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


## 产品介绍与开源许可

根目录 `README.md` 仅提供本产品简明介绍，不承载技术方案、任务记录或验收结论。独立自有代码采用根 `LICENSE` 的MIT；上游代码、衍生修改、依赖及组合分发遵循各自原许可、版权、例外与附加要求。

原生第一方引擎的Cargo许可元数据与仓根MIT全文一致；OpenMLS等上游依赖保持各自原许可，禁止把项目MIT声明扩展到上游源码或依赖。

本次依赖统一同时覆盖归档差分测试的第一方smoldot C ABI适配及hex/parking_lot直接声明；对应Cargo锁与SDK冻结摘要原子同步。上游PoW与libp2p内部闭包仍按来源保留，不把第一方适配当成上游例外。全17仓直接声明回归按准确源码归属检查Cargo、Pub与npm，逐项读取所属产品真实原锁。

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



## 2026-10-08 服务模块接线与 lib 目录收口

lib 下直接按 attachment、call、core、group、mls、protocol、runtime、storage、transport、ui 分工，公开入口保留 lib/tatachat_sdk.dart。原 src 层已删除，没有旧路径别名；五份 proto 及生成代码仅移动，不改变协议字节或存储 schema。

Host.requestChatAccess 返回 ChatAccess(realtimeUrl, accessToken, expiresAtMillis)。地址必须是完整 wss://<origin>/api/tatachat/realtime，无用户信息、查询或片段；SDK 不解析不透明 accessToken，不落盘或输出它。每次物理连接取得新许可，账户、绑定范围和修订在请求前后固定复核。附件地址由同主机/端口派生 https://<origin>/api/tatachat/attachments/{id}/chunks/{index}，TLS 和禁止重定向在实际请求上执行。

连接按代际丢弃迟到结果，等待许可、握手、Ready、当前命令各有12秒截止；队列最多128条，控制帧最多2MiB，分块最多4MiB。临近许可到期60秒即停止 socket 与所属 HTTP 请求。关闭失败保留可重试资源，不能把失败 Ready 或未回收请求当已完成关闭。系统通知只承载无正文 chat_wake。

正式dart:io连接使用WebSocket.pingInterval执行25秒协议级保活，Pong也按原生25秒期限检测；不发送定时Protobuf业务Ping，不保留另一套应用层保活计时器。平台可在不唤醒DO时回复协议级Ping；保活不代表业务授权通过，原业务鉴权、60秒宿主复核和许可终期保持。未请求的应用层Pong仍拒绝，等待许可、握手、Ready和命令的12秒截止不变。

账户补拉单飞，每批最多100条，先验密和本机精确持久收据再 ACK。字节裁剪的短批仍继续；仅空批收敛。无 ACK 进展按1/2/4秒最多三次补拉后等待下次外部触发；一轮最多32批或15秒，仍有进展时安排250毫秒后续轮次。停止、擦除和换绑拒绝旧结果及迟到 ACK；云端七天密文暂存不会替代本机永久历史。

附件沿用原待发记录的创建时间、ID、受众和密文摘要，先用幂等 complete 核对 Ready 回执；未知网络/写入/完成结果保留原密文，禁止自动 abort 或写成功标记。未得到完成证明时仅以同元数据继续 begin/分块；用户取消、受众失效或到期仍归现有终结清理入口。




## 可等待的宿主附件准备（前后端联调第2步）

ChatConversationHost.prepareAttachment为可选Future<void> Function(String userId)。SDK在选图/文件/拍摄、开始录音、媒体处理及实际附件发送前await它；文字、表情、页面打开和重连不调用。宿主负责合并进行中的请求、核对当前账户/设备/会话、会员与有效期限；SDK不导入公民会员模型，不直接调用CitizenServe或查链。缺省null保持其他产品原行为。

同一次附件过程可能在选取前和发送前分别核对，以覆盖长时间选取/录制和中途失效；宿主复用同一Future/短期结果，不能为每次回调重新请求。异常沿原错误显示停止动作，已切用户/账户/会话或已销毁页面的迟到结果不得继续处理/发送。原文件归属、媒体大小、时长、上传与清理约束保持。


第2步运行时附件边界：原ChatRuntimeHost保持，产品可选择实现同文件ChatAttachmentAuthorizationHost.prepareAttachment(account, allowRefresh, expectedDeviceId)。SDK只等待布尔许可并复核原账户/绑定围栏，不解释会员。主动sendMedia/sendGroupAttachment在大小/加密前以及长加密后复核；主动downloadAttachment可刷新。自动上传/补发、入站及页面自动补取只用缓存，不主动刷新；缓存缺失/过期保留原待发密文和控制消息。直聊普通消息继续，群聊沿原顺序；没有新缓存、计时器或状态表。有效缓存取得后可继续原重试，原受众/MLS/文件清理/服务端权限保持。

运行时新附件ID仅含ASCII字母、数字、下划线及连字符，并保持1～128字符，沿用原MLS/HTTP严格校验。生成器保留毫秒值和128位安全随机数；会话归属仍由原绑定围栏、受众和服务端检查确定。

## 外部调用入口



配置文件仅保留配置数据及release/cleanup入口声明，执行函数唯一归既有scripts/build.mjs。自动化等待原Run真实结束后实际删除旧同类Run及其日志、Artifact，旧发布资产按既有producer_run_id回执归属删除，最新成功完整交付确认后才清理旧成功；活动任务保护，失败清理独立进行。清理失败明确报错，可单独调用同一cleanup入口，不重跑构建；Workflow只负责本次正式Release/Tag交付及回滚，旧历史没有第二套清理。

本产品scripts/config.mjs的describeAction仅返回repository、workflow、ref、inputs，或既有本地进程命令声明；不导入构建实现、不派发GitHub请求、不处理令牌、版本或历史。控制台使用统一数据接口直接派发并只读观察准确Run；产品GitHub业务归所属既有YAML。本次自动化Run名称使用运行编号，正式构建及产物保持版本名称。已有工具和依赖复用，缺少时才按原声明准备。


## MLS目录与初始化阶段

平台插件先核验SDK目录及系统保护，Dart只将合法系统容器别名规范到同一实际目录；末级链接、非目录与不可读分别用固定错误分类拒绝。身份普通准备与聊天初始化共用prepareIdentity，不能只按本次mkdir结果判断已有身份。state.lock在同一flock内记录initializing或committed：生成前同步initializing，完整state.bin原子提交、归属验证及committed同步完成后才交付身份。提交后回执丢失读取原快照；committed缺文件永不自动换钥；合法空目录及空锁由prepare自动完成，无手动初始化入口、确认错误码或首次目录标志。离线准备不登记网络设备、不触发钱包签名。状态损坏和未知目录内容失败关闭。读证明不生成身份，签名载荷和原生C ABI保持。阶段失败及临时写中断、并发确认、错误归属、路径别名与链接均用合成状态回归。

自动准备固定账户、用户、绑定版本、绑定域、宿主索引和账户代次；关闭/封禁后不交付旧结果。SDK既有合同测试验证自动准备前的账户变化不产生原生动作、返回后的绑定变化不交付旧身份；通讯录真实FFI回归验证签读不补密钥、离线自动准备后复用同一身份同步。平台路径测试使用原MethodChannel及合成系统临时目录，对系统别名规范化与末级链接拒绝分别断言。

初始化阶段同时绑定所属用户的固定摘要，只存于SDK保护目录；它不进入诊断、页面或日志。尚未交付阶段也不能被另一用户续行；摘要或阶段损坏且无快照时拒绝自动生成身份。

测试中的MLS目录与运行态目录必须像生产一样分离；不能在MLS目录放入运行态互斥或偏好文件后放宽原生目录内容校验。普通认证夹具仅接受read和sign_authentication，自动准备夹具仅接受prepare并返回合成公开身份。

阶段只写单链接的普通state.lock描述符；硬链接拒绝且不改原字节，防止新增阶段写入影响SDK目录外文件。目录不可读不直接推定设备锁屏，页面显示固定稍后重试提示。

硬链接回归在允许构造的宿主实际验证SDK拒绝；Android shell若被内核明确PermissionDenied阻止构造，则断言系统拒绝、单链接及原身份/字节不变，不将该结果宣称为已触发SDK硬链接分支。其他准备失败仍使测试失败，不跳过。

本地身份自动准备复用运行态既有_requireCurrentAccount守卫，确保绑定域、宿主和撤销代次只有一条判定路径。路径规范化阶段的缺目录与非目录分别归类，不泄露系统异常正文。

自动准备回归覆盖目录创建后中断、已有空锁、提交回执中断、并发一致性、错误归属、损坏/缺失不换钥及绑定晚回。内部文件提交阶段仅用于持久化事务，不形成宿主用户身份状态；钱包和公民号事实由宿主拥有，读取失败作为操作错误，不写成无公民号。宿主消费准备后的同一公开设备身份接入自己的服务认证；SDK不接入Turnstile或CID交易，不提供初始化页面、按钮或独立手动准备入口。

自动准备在原生返回及用户文件屏障退出后都复核当前账户和运行态，关闭或迟到绑定变化不得交付身份。准备夹具与严格认证夹具分开，不能放宽认证只读约束；真实FFI测试动态库必须复制到本轮独占验证现场后加载。


## 服务端资源回执合同
chat_frame.proto是ResourceUsage/ResourceCounter及ChatFrame.resource_usage的唯一协议源，原生成文件同步。回执只由服务端响应填写，字段为宿主用户/设备/账户/修订、服务端时间、指标窗口及实际扣量/已用/可选上限；协议不解释会员或数据库。旧命令编号和密文保持，回执大小纳入出站帧上限。回执与原命令由相同协议往返测试覆盖；中性宿主预检沿ChatAccess.resources消费此回执。

ChatAccess可由宿主交付中性ChatResourceGate。正式连接在socket之前预检，命令在队头实际编码完成后预检，响应期限从实际发送开始；连接预检以请求局部持有预留，取消期间迟到钩子释放未发送预留且不能打开socket；命令队列取消也不能迟到发送。命令只编码一次，原帧字节硬顶继续校验，同份字节向宿主交付不可修改视图后用于发送。实际socket发送失败仍关闭连接并保留固定错误码，不能当成本地预检拒绝继续复用坏连接。每次实际附件PUT/GET使用真实密文长度独立预检，重试再次经过同一钩子；服务端资源回执原样交付宿主，包括失败帧及其真实错误码，宿主可以区分附件不存在与恢复已有附件。SDK不持有会员档位、额度或第二用量账本；未接入此可选宿主能力的其他产品沿原服务端校验。

### 宿主用量精简

SDK继续只交付实际连接、命令及附件传输事实，不定义会员数值或计量账本。CitizenServe宿主已将会员日计量收敛为统一媒体请求/下发、附件上传字节及新建附件许可；分块仍是传输机制，不存在独立分块额度。无计量的动作仍可执行宿主身份校验并返回空counter_list；SDK不能自行恢复已删除的连接、命令、投递额度。现有ResourceUsage及通用钩子不增加字段；宿主容量统一用整数字节，展示1024单位由消费产品完成。

附件系统选择的唯一大小输入由ChatAttachmentPlatform.pickFile(maxBytes:)交付，聊天页面读取宿主mediaLimits的file规则；Android/iOS在读取前及流式复制中均校验同份整数字节上限，删除固定512MiB限额。无效上限在打开选择器前拒绝，系统取消、单文件、沙箱及临时文件清理保持。附件HTTP的5xx以storage_unavailable交付原资源钩子，让宿主保留缺回执的未知消耗；SDK不建立会员账本或改变聊天协议。


本机持久化保持conversation/message/outbound/media/inbound/route/group/member/commit/fence十集合，含必需row_id共85列。Dart实体与成员遵循UpperCamelCase/lowerCamelCase，物理名称由官方@Name表达。media以ownerUserId/attachmentId/recipientUserId三元唯一，member以ownerUserId/groupId/memberUserId三元唯一，不存拼接键；群名只归group，人数直接读member，会话时间成员为updatedAtMillis、物理列updated_at。

出站队列仅表示真实待投递事实，不复制消息展示状态，也不保存无人消费的尝试计数、末次错误。入站缓冲不保存不参与回放的原因文本；群与成员镜像删除无人消费的创建/更新时间和加入时间，内部存储参数及实际调用同步删除。消息发送设备保留在冻结MLS原字节，不另存无人读取的列。epoch、角色、退群状态、Commit到达顺序、签发绑定、围栏和逐收件人重试密文保留；失败分类、重试、ACK及原收件集合保持。真实旧库不由普通打开迁移或清除。

媒体描述发送成员身份统一senderIdentity/sender_identity，Proto字段15、类型及原字节保持。MLS认证证明由原生Serde唯一编码，字段为user_id/device_id/public_key/account_id/bind_rev/service_origin/nonce_id/expires_at/http_method/request_target/body_hash/signature。user_id保持部署中性的宿主身份，原签名域、顺序、毫秒单位及签名字节保持；Dart只持有原生唯一字段集，宿主可验证而不回抄另一份证明。ResourceUsage沿原Proto类型与编号，由宿主直接消费公开类型，不另建计量模型。
