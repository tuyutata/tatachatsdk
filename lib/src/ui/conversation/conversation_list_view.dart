import 'package:flutter/material.dart';

import '../style.dart';

class ChatHeaderAction<T> {
  const ChatHeaderAction({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final String label;
  final Widget icon;
}

/// Reusable title and anchored action menu for a chat overview.
class ChatSectionHeader<T> extends StatelessWidget {
  const ChatSectionHeader({
    super.key,
    required this.actions,
    required this.onAction,
    this.title = '聊天',
    this.style = const ChatViewStyle(),
  });

  final String title;
  final List<ChatHeaderAction<T>> actions;
  final ValueChanged<T> onAction;
  final ChatViewStyle style;

  Future<void> _open(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final origin = box.localToGlobal(Offset.zero);
    final selected = await showGeneralDialog<T>(
      context: buttonContext,
      barrierDismissible: true,
      barrierLabel: '关闭新建菜单',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (_, __, ___) => _ChatEntryMenu<T>(
        anchorCenterX: origin.dx + box.size.width / 2,
        top: origin.dy + box.size.height + 2,
        actions: actions,
        style: style,
      ),
      transitionBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    );
    if (selected != null) onAction(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 24, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: style.scale(context, 24),
                fontWeight: FontWeight.w700,
                color: style.textPrimary(context),
              ),
            ),
          ),
          Builder(
            builder: (buttonContext) => Container(
              key: const ValueKey('chat-add-button'),
              width: style.scale(context, 28),
              height: style.scale(context, 28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: style.primary(context), width: 1.25),
              ),
              child: IconButton(
                tooltip: '新建',
                padding: EdgeInsets.zero,
                iconSize: style.scale(context, 16),
                constraints: BoxConstraints.tightFor(
                  width: style.scale(context, 28),
                  height: style.scale(context, 28),
                ),
                icon: Icon(Icons.add_rounded, color: style.primary(context)),
                onPressed: () => _open(buttonContext),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatConversationListItem {
  const ChatConversationListItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.updatedAt,
    required this.unreadCount,
    required this.leading,
    required this.onTap,
    required this.onDelete,
    this.onLongPress,
  });

  final String id;
  final String title;
  final String subtitle;
  final DateTime updatedAt;
  final int unreadCount;
  final Widget leading;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;
  final VoidCallback? onLongPress;
}

/// Reusable conversation list, search entry, status and unread UI.
class ChatConversationOverview extends StatelessWidget {
  const ChatConversationOverview({
    super.key,
    required this.header,
    required this.onRefresh,
    required this.onSearch,
    required this.items,
    this.loading = false,
    this.errorMessage,
    this.unavailable,
    this.loadingLabel = '正在读取本地会话',
    this.emptyLabel = '暂无会话',
    this.style = const ChatViewStyle(),
  });

  final Widget header;
  final Future<void> Function() onRefresh;
  final VoidCallback onSearch;
  final List<ChatConversationListItem> items;
  final bool loading;
  final String? errorMessage;
  final Widget? unavailable;
  final String loadingLabel;
  final String emptyLabel;
  final ChatViewStyle style;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ColoredBox(
        color: style.background(context),
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: onRefresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: header),
                  if (errorMessage != null)
                    SliverToBoxAdapter(
                      child: _ErrorBanner(message: errorMessage!, style: style),
                    ),
                  SliverToBoxAdapter(
                    child: _SearchEntry(onTap: onSearch, style: style),
                  ),
                  if (loading && items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: ChatConversationPlaceholder(
                        message: loadingLabel,
                        style: style,
                      ),
                    )
                  else if (unavailable != null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: unavailable!,
                    )
                  else if (items.isNotEmpty)
                    SliverList.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) => _ConversationTile(
                        item: items[index],
                        isFirst: index == 0,
                        isLast: index == items.length - 1,
                        style: style,
                      ),
                    )
                  else
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: ChatConversationPlaceholder(
                        message: emptyLabel,
                        style: style,
                      ),
                    ),
                ],
              ),
            ),
            if (loading)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: LinearProgressIndicator(
                    key: const ValueKey('chat-sync-progress'),
                    minHeight: style.scale(context, 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ChatConversationPlaceholder extends StatelessWidget {
  const ChatConversationPlaceholder({
    super.key,
    required this.message,
    this.style = const ChatViewStyle(),
  });

  final String message;
  final ChatViewStyle style;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 80),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: style.textSecondary(context),
            fontSize: style.scale(context, 15),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.item,
    required this.isFirst,
    required this.isLast,
    required this.style,
  });

  final ChatConversationListItem item;
  final bool isFirst;
  final bool isLast;
  final ChatViewStyle style;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.vertical(
      top: isFirst ? Radius.circular(style.scale(context, 12)) : Radius.zero,
      bottom: isLast ? Radius.circular(style.scale(context, 12)) : Radius.zero,
    );
    return Dismissible(
      key: ValueKey('chat-conversation-${item.id}'),
      direction: DismissDirection.endToStart,
      background: _DeleteDismissBackground(style: style),
      confirmDismiss: (_) async {
        await item.onDelete();
        return false;
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: style.scale(context, 16)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: style.surface(context),
            borderRadius: radius,
            border: Border.all(color: style.border(context)),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: radius,
              onTap: item.onTap,
              onLongPress: item.onLongPress,
              child: Padding(
                padding: EdgeInsets.all(style.scale(context, 14)),
                child: Row(
                  children: [
                    item.leading,
                    SizedBox(width: style.scale(context, 12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: style.textPrimary(context),
                            ),
                          ),
                          SizedBox(height: style.scale(context, 4)),
                          Text(
                            item.subtitle.trim().isEmpty
                                ? '暂无消息'
                                : item.subtitle.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: style.scale(context, 13),
                              color: style.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: style.scale(context, 10)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          chatConversationTime(item.updatedAt),
                          style: TextStyle(
                            fontSize: style.scale(context, 12),
                            color: style.textSecondary(context),
                          ),
                        ),
                        if (item.unreadCount > 0) ...[
                          SizedBox(height: style.scale(context, 6)),
                          CircleAvatar(
                            radius: style.scale(context, 10),
                            backgroundColor: style.primary(context),
                            child: Text(
                              '${item.unreadCount}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: style.scale(context, 11),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchEntry extends StatelessWidget {
  const _SearchEntry({required this.onTap, required this.style});

  final VoidCallback onTap;
  final ChatViewStyle style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(style.scale(context, 10)),
        child: InkWell(
          borderRadius: BorderRadius.circular(style.scale(context, 10)),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: style.scale(context, 16),
              vertical: style.scale(context, 12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: style.scale(context, 20),
                  color: style.textTertiary(context),
                ),
                SizedBox(width: style.scale(context, 8)),
                Expanded(
                  child: Text(
                    '搜索会话、联系人和聊天记录',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: style.textTertiary(context),
                      fontSize: style.scale(context, 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteDismissBackground extends StatelessWidget {
  const _DeleteDismissBackground({required this.style});

  final ChatViewStyle style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: style.scale(context, 16)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(style.scale(context, 8)),
        ),
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(right: style.scale(context, 20)),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.style});

  final String message;
  final ChatViewStyle style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Text(
        message,
        style: TextStyle(
          color: style.error(context),
          fontSize: style.scale(context, 12),
        ),
      ),
    );
  }
}

class _ChatEntryMenu<T> extends StatelessWidget {
  const _ChatEntryMenu({
    required this.anchorCenterX,
    required this.top,
    required this.actions,
    required this.style,
  });

  final double anchorCenterX;
  final double top;
  final List<ChatHeaderAction<T>> actions;
  final ChatViewStyle style;

  static const double _width = 116;
  static const double _caretWidth = 14;
  static const double _caretHeight = 7;
  static const double _edgeGap = 8;
  static const double _panelRadius = 12;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final rawLeft = anchorCenterX - _width + 24;
    final left = rawLeft.clamp(_edgeGap, screenWidth - _width - _edgeGap);
    final caretCenter = (anchorCenterX - left).clamp(
      _panelRadius + _caretWidth / 2,
      _width - _panelRadius - _caretWidth / 2,
    );
    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(left: caretCenter - _caretWidth / 2),
                child: CustomPaint(
                  size: const Size(_caretWidth, _caretHeight),
                  painter: _CaretPainter(style.menuColor),
                ),
              ),
              Material(
                color: style.menuColor,
                borderRadius: BorderRadius.circular(style.scale(context, 12)),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: _width,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: style.scale(context, 4)),
                      for (final action in actions)
                        InkWell(
                          onTap: () =>
                              Navigator.of(context).pop<T>(action.value),
                          child: SizedBox(
                            height: style.scale(context, 40),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 22, 0),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: style.scale(context, 20),
                                    height: style.scale(context, 20),
                                    child: Center(child: action.icon),
                                  ),
                                  SizedBox(width: style.scale(context, 12)),
                                  Text(
                                    action.label,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: style.scale(context, 15),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      SizedBox(height: style.scale(context, 4)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CaretPainter extends CustomPainter {
  const _CaretPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const tipInset = 2.2;
    final half = size.width / 2;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(half - tipInset, tipInset)
      ..quadraticBezierTo(half, 0, half + tipInset, tipInset)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CaretPainter oldDelegate) => oldDelegate.color != color;
}

String chatConversationTime(DateTime value, {DateTime? now}) {
  final local = value.toLocal();
  final localNow = (now ?? DateTime.now()).toLocal();
  final day = DateTime(local.year, local.month, local.day);
  final today = DateTime(localNow.year, localNow.month, localNow.day);
  final difference = today.difference(day).inDays;
  if (difference == 0) {
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
  if (difference == 1) return '昨天';
  if (difference > 1 && difference < 7) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays[local.weekday - 1];
  }
  return '${local.month}/${local.day}';
}
