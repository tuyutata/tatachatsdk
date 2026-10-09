import 'package:flutter/material.dart';

import '../metrics.dart';

/// Default action set for a direct or group conversation.
enum ChatComposerAction {
  gallery,
  capture,
  videoCall,
  voiceCall,
  transfer,
  location,
  file,
}

/// Allows a host to replace one icon without owning the panel layout.
///
/// Return null to use TataChatSDK's default Material icon.
typedef ChatComposerActionIconBuilder =
    Widget? Function(
      BuildContext context,
      ChatComposerAction action,
      Color color,
      double size,
    );

/// Four-column action grid. Group conversations hide transfer and disable calls.
class ComposerActionPanel extends StatelessWidget {
  const ComposerActionPanel({
    super.key,
    required this.isGroup,
    required this.onAction,
    this.callsEnabled = false,
    this.iconBuilder,
  });

  final bool isGroup;
  final bool callsEnabled;
  final ValueChanged<ChatComposerAction> onAction;
  final ChatComposerActionIconBuilder? iconBuilder;

  static const _items = <_ActionItem>[
    _ActionItem(ChatComposerAction.gallery, Icons.photo_library_rounded, '相册'),
    _ActionItem(ChatComposerAction.capture, Icons.photo_camera_rounded, '拍摄'),
    _ActionItem(ChatComposerAction.videoCall, Icons.videocam_rounded, '视频通话'),
    _ActionItem(ChatComposerAction.voiceCall, Icons.call_rounded, '语音通话'),
    _ActionItem(
      ChatComposerAction.transfer,
      Icons.currency_exchange_rounded,
      '转账',
    ),
    _ActionItem(
      ChatComposerAction.location,
      Icons.location_on_rounded,
      '位置',
      unavailable: true,
    ),
    _ActionItem(ChatComposerAction.file, Icons.insert_drive_file_rounded, '文件'),
  ];

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final item in _items)
        if (!(isGroup && item.action == ChatComposerAction.transfer))
          item.copyWith(
            disabled:
                (!callsEnabled || isGroup) &&
                (item.action == ChatComposerAction.videoCall ||
                    item.action == ChatComposerAction.voiceCall),
          ),
    ];
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      key: const ValueKey('chat-composer-action-panel'),
      color: colors.surface,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          ChatUiMetrics.scaled(context, 18),
          ChatUiMetrics.scaled(context, 18),
          ChatUiMetrics.scaled(context, 18),
          ChatUiMetrics.scaled(context, 22),
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisExtent: ChatUiMetrics.scaled(context, 86),
          mainAxisSpacing: ChatUiMetrics.scaled(context, 12),
          crossAxisSpacing: ChatUiMetrics.scaled(context, 14),
        ),
        itemCount: items.length,
        itemBuilder: (context, index) => _ActionButton(
          item: items[index],
          iconBuilder: iconBuilder,
          onTap: () => onAction(items[index].action),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.item,
    required this.onTap,
    this.iconBuilder,
  });

  final _ActionItem item;
  final VoidCallback onTap;
  final ChatComposerActionIconBuilder? iconBuilder;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = item.unavailable || item.disabled
        ? colors.onSurfaceVariant.withValues(alpha: 0.48)
        : colors.onSurface;
    final iconSize = ChatUiMetrics.scaled(context, 25);
    final customIcon = iconBuilder?.call(
      context,
      item.action,
      foreground,
      iconSize,
    );
    return Semantics(
      button: true,
      enabled: !item.disabled,
      label: item.disabled
          ? '${item.label}，暂不支持'
          : item.unavailable
          ? '${item.label}，功能完善中'
          : item.label,
      child: InkWell(
        key: ValueKey('chat-action-${item.action.name}'),
        borderRadius: BorderRadius.circular(ChatUiMetrics.scaled(context, 14)),
        onTap: item.disabled ? null : onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: ChatUiMetrics.scaled(context, 56),
              height: ChatUiMetrics.scaled(context, 56),
              decoration: BoxDecoration(
                color: item.unavailable
                    ? colors.surfaceContainerHigh.withValues(alpha: 0.6)
                    : colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(
                  ChatUiMetrics.scaled(context, 14),
                ),
              ),
              alignment: Alignment.center,
              child:
                  customIcon ??
                  Icon(item.icon, size: iconSize, color: foreground),
            ),
            SizedBox(height: ChatUiMetrics.scaled(context, 6)),
            Text(
              item.label,
              maxLines: 1,
              style: TextStyle(
                color: foreground,
                fontSize: ChatUiMetrics.scaled(context, 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionItem {
  const _ActionItem(
    this.action,
    this.icon,
    this.label, {
    this.unavailable = false,
    this.disabled = false,
  });

  final ChatComposerAction action;
  final IconData icon;
  final String label;
  final bool unavailable;
  final bool disabled;

  _ActionItem copyWith({bool? disabled}) => _ActionItem(
    action,
    icon,
    label,
    unavailable: unavailable,
    disabled: disabled ?? this.disabled,
  );
}
