import 'package:flutter/material.dart';

import 'style.dart';

class ChatSelectableUser {
  const ChatSelectableUser({
    required this.userId,
    required this.displayName,
    this.subtitle,
  });

  final String userId;
  final String displayName;
  final String? subtitle;
}

/// 通用群创建表单；联系人和创建动作由宿主提供。
class ChatGroupCreateView extends StatelessWidget {
  const ChatGroupCreateView({
    super.key,
    required this.nameController,
    required this.users,
    required this.selectedUserIds,
    required this.onSelectionChanged,
    required this.canCreate,
    required this.onCreate,
    this.loading = false,
    this.creating = false,
    this.error,
    this.emptyMessage = '通讯录为空',
    this.style = const ChatViewStyle(),
  });

  final TextEditingController nameController;
  final List<ChatSelectableUser> users;
  final Set<String> selectedUserIds;
  final void Function(String userId, bool selected) onSelectionChanged;
  final bool canCreate;
  final VoidCallback onCreate;
  final bool loading;
  final bool creating;
  final String? error;
  final String emptyMessage;
  final ChatViewStyle style;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新建群聊'),
        actions: [
          TextButton(
            onPressed: canCreate && !creating ? onCreate : null,
            child: creating
                ? SizedBox(
                    width: style.scale(context, 18),
                    height: style.scale(context, 18),
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('创建'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (loading)
            LinearProgressIndicator(
              key: const ValueKey('group-create-load-progress'),
              minHeight: style.scale(context, 2),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: nameController,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: '群名称',
                counterText: '',
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: style.scale(context, 16)),
            child: Row(
              children: [
                Text('选择成员', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Text(
                  selectedUserIds.length < 2
                      ? '已选 ${selectedUserIds.length}·至少 2 人'
                      : '已选 ${selectedUserIds.length}',
                ),
              ],
            ),
          ),
          if (error != null)
            Padding(
              padding: EdgeInsets.all(style.scale(context, 16)),
              child: Text(
                error!,
                style: TextStyle(color: style.error(context)),
              ),
            ),
          Expanded(
            child: loading && users.isEmpty
                ? const Center(child: Text('正在读取本地通讯录'))
                : users.isEmpty
                ? Center(child: Text(emptyMessage))
                : ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final selected = selectedUserIds.contains(user.userId);
                      return CheckboxListTile(
                        value: selected,
                        onChanged: (value) =>
                            onSelectionChanged(user.userId, value ?? false),
                        title: Text(user.displayName),
                        subtitle: user.subtitle == null
                            ? null
                            : Text(
                                user.subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ChatGroupMemberItem {
  const ChatGroupMemberItem({
    required this.userId,
    required this.displayName,
    required this.isAdmin,
    required this.canRemove,
    this.onRemove,
  });

  final String userId;
  final String displayName;
  final bool isAdmin;
  final bool canRemove;
  final VoidCallback? onRemove;
}

/// 通用群成员列表及管理页面。
class ChatGroupManageView extends StatelessWidget {
  const ChatGroupManageView({
    super.key,
    required this.title,
    required this.members,
    required this.isAdmin,
    required this.onLeave,
    this.onRename,
    this.onAddMembers,
    this.loading = false,
    this.busy = false,
    this.groupAvailable = true,
    this.error,
    this.memberLimit = 1989,
    this.style = const ChatViewStyle(),
  });

  final String title;
  final List<ChatGroupMemberItem> members;
  final bool isAdmin;
  final VoidCallback onLeave;
  final VoidCallback? onRename;
  final VoidCallback? onAddMembers;
  final bool loading;
  final bool busy;
  final bool groupAvailable;
  final String? error;
  final int memberLimit;
  final ChatViewStyle style;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: '改群名',
              icon: const Icon(Icons.edit_outlined),
              onPressed: busy ? null : onRename,
            ),
        ],
      ),
      body: Column(
        children: [
          if (loading)
            LinearProgressIndicator(
              key: const ValueKey('group-manage-load-progress'),
              minHeight: style.scale(context, 2),
            ),
          if (error != null)
            Padding(
              padding: EdgeInsets.all(style.scale(context, 16)),
              child: Text(
                error!,
                style: TextStyle(color: style.error(context)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(
                  '成员 ${groupAvailable ? members.length : '--'} / $memberLimit',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                if (isAdmin)
                  TextButton.icon(
                    onPressed: busy ? null : onAddMembers,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('添加'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: !groupAvailable
                ? Center(child: Text(loading ? '正在读取群聊信息' : '群不存在或已退出'))
                : ListView(
                    children: [
                      for (final member in members)
                        ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              member.userId.isEmpty
                                  ? '?'
                                  : member.userId.substring(0, 1),
                            ),
                          ),
                          title: Text(member.displayName),
                          subtitle: member.isAdmin ? const Text('管理员') : null,
                          trailing: member.canRemove
                              ? IconButton(
                                  tooltip: '移除',
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: busy ? null : member.onRemove,
                                )
                              : null,
                        ),
                    ],
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(style.scale(context, 16)),
              child: OutlinedButton.icon(
                onPressed: loading || !groupAvailable || busy ? null : onLeave,
                icon: const Icon(Icons.exit_to_app),
                label: const Text('退出群聊'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: style.error(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> showChatRenameGroupDialog(
  BuildContext context, {
  required String currentName,
}) async {
  final controller = TextEditingController(text: currentName);
  try {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改群名'),
        content: TextField(
          controller: controller,
          maxLength: 40,
          decoration: const InputDecoration(counterText: ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  } finally {
    controller.dispose();
  }
}

Future<bool> showChatLeaveGroupDialog(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('退出群聊'),
          content: const Text('退群后将收不到后续消息。确定退出？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('退出'),
            ),
          ],
        ),
      ) ??
      false;
}

Future<List<String>?> showChatUserPickerDialog(
  BuildContext context, {
  required List<ChatSelectableUser> users,
}) {
  final selected = <String>{};
  return showDialog<List<String>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: const Text('添加成员'),
        content: SizedBox(
          width: double.maxFinite,
          child: users.isEmpty
              ? const Text('没有可添加的联系人')
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final user in users)
                      CheckboxListTile(
                        value: selected.contains(user.userId),
                        onChanged: (value) => setLocal(() {
                          if (value ?? false) {
                            selected.add(user.userId);
                          } else {
                            selected.remove(user.userId);
                          }
                        }),
                        title: Text(user.displayName),
                        subtitle: user.subtitle == null
                            ? null
                            : Text(user.subtitle!),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(selected.toList(growable: false)),
            child: const Text('添加'),
          ),
        ],
      ),
    ),
  );
}
