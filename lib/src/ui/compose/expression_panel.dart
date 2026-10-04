import 'dart:math' as math;

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

import '../sticker_panel.dart';
import '../style.dart';

enum ChatComposerPanel { none, expression, actions }

enum ChatExpressionTab { emoji, sticker }

/// Reusable emoji/sticker panel. Product entitlement remains a host concern.
class ChatExpressionPanel extends StatelessWidget {
  const ChatExpressionPanel({
    super.key,
    required this.controller,
    required this.selectedTab,
    required this.onTabChanged,
    required this.onStickerPick,
    required this.onSendText,
    this.style = const ChatViewStyle(),
  });

  final TextEditingController controller;
  final ChatExpressionTab selectedTab;
  final ValueChanged<ChatExpressionTab> onTabChanged;
  final void Function(String packId, String stickerId) onStickerPick;
  final ValueChanged<String> onSendText;
  final ChatViewStyle style;

  @override
  Widget build(BuildContext context) {
    final height = math.min(304.0, MediaQuery.sizeOf(context).height * 0.44);
    return SizedBox(
      key: const ValueKey('chat-expression-panel'),
      height: height,
      child: Column(
        children: [
          SizedBox(
            height: style.scale(context, 42),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _tabButton(context, ChatExpressionTab.emoji, '表情'),
                SizedBox(width: style.scale(context, 18)),
                _tabButton(context, ChatExpressionTab.sticker, '贴纸'),
              ],
            ),
          ),
          Expanded(
            child: selectedTab == ChatExpressionTab.emoji
                ? Column(
                    children: [
                      Expanded(
                        child: EmojiPicker(
                          key: const ValueKey('chat-emoji-picker'),
                          textEditingController: controller,
                          config: Config(
                            height: height - style.scale(context, 90),
                            checkPlatformCompatibility: true,
                            emojiViewConfig: EmojiViewConfig(
                              columns: 8,
                              backgroundColor: style.surface(context),
                            ),
                            categoryViewConfig: CategoryViewConfig(
                              backgroundColor: style.surface(context),
                              indicatorColor: style.accent(context),
                              iconColorSelected: style.accent(context),
                              backspaceColor: style.accent(context),
                            ),
                            bottomActionBarConfig: const BottomActionBarConfig(
                              enabled: false,
                            ),
                          ),
                        ),
                      ),
                      _bottomActionBar(context),
                    ],
                  )
                : StickerPanel(
                    height: height - style.scale(context, 42),
                    onPick: onStickerPick,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _bottomActionBar(BuildContext context) {
    return SizedBox(
      height: style.scale(context, 48),
      child: ColoredBox(
        color: style.surface(context),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            BackspaceButton(
              key: const ValueKey('chat-emoji-backspace'),
              const Config(),
              () => _deleteText(deleteWord: false),
              () => _deleteText(deleteWord: true),
              style.textSecondary(context),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, child) => IconButton(
                key: const ValueKey('chat-emoji-send'),
                tooltip: '发送',
                color: style.accent(context),
                disabledColor: style.textTertiary(context),
                onPressed: value.text.trim().isEmpty ? null : _sendDraft,
                icon: const Icon(Icons.send_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(BuildContext context, ChatExpressionTab tab, String label) {
    final selected = selectedTab == tab;
    return TextButton(
      key: ValueKey('chat-expression-${tab.name}'),
      onPressed: () => onTabChanged(tab),
      child: Text(
        label,
        style: TextStyle(
          color: selected
              ? style.accent(context)
              : style.textSecondary(context),
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }

  void _deleteText({required bool deleteWord}) {
    final value = controller.value;
    final text = value.text;
    if (text.isEmpty) return;
    final selection = value.selection;
    final hasSelection = selection.isValid && !selection.isCollapsed;
    final start = hasSelection
        ? math.min(selection.start, selection.end)
        : (selection.isValid ? selection.extentOffset : text.length).clamp(
            0,
            text.length,
          );
    final end = hasSelection ? math.max(selection.start, selection.end) : start;
    if (hasSelection) {
      final next = text.replaceRange(start, end, '');
      controller.value = value.copyWith(
        text: next,
        selection: TextSelection.collapsed(offset: start),
        composing: TextRange.empty,
      );
      return;
    }
    if (start == 0) return;
    final before = text.substring(0, start);
    final retained = deleteWord
        ? before.replaceFirst(RegExp(r'(?:\s+|\S+\s*)$'), '')
        : before.characters.skipLast(1).toString();
    final next = '$retained${text.substring(start)}';
    controller.value = value.copyWith(
      text: next,
      selection: TextSelection.collapsed(offset: retained.length),
      composing: TextRange.empty,
    );
  }

  void _sendDraft() {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    controller.clear();
    onSendText(text);
  }
}
