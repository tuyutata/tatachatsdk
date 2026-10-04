/// TataChatSDK 顶层会话分类；四类消息能力分别在私聊和群聊中实现。
enum ChatScope { direct, group }

/// 密文邮箱的统一最长保留时间，重试不得刷新该期限。
const Duration chatSdkMessageRetention = Duration(days: 7);
