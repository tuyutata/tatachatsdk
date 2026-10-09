import 'package:flutter/material.dart';

import '../style.dart';

class ChatSearchItem {
  const ChatSearchItem({
    required this.key,
    required this.leading,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final Key key;
  final Widget leading;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
}

class ChatSearchSection {
  const ChatSearchSection({required this.title, required this.items});

  final String title;
  final List<ChatSearchItem> items;
}

/// Reusable local search screen; hosts inject authorized data and navigation.
class ChatSearchView extends StatelessWidget {
  const ChatSearchView({
    super.key,
    required this.controller,
    required this.query,
    required this.onQueryChanged,
    required this.onClear,
    required this.sections,
    this.loading = false,
    this.searching = false,
    this.error,
    this.style = const ChatViewStyle(),
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClear;
  final List<ChatSearchSection> sections;
  final bool loading;
  final bool searching;
  final String? error;
  final ChatViewStyle style;

  @override
  Widget build(BuildContext context) {
    final hasQuery = query.isNotEmpty;
    final noHit =
        hasQuery && sections.every((section) => section.items.isEmpty);
    return Scaffold(
      backgroundColor: style.background(context),
      appBar: AppBar(
        title: const Text('搜索'),
        actions: [
          if (hasQuery) TextButton(onPressed: onClear, child: const Text('清除')),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              key: const ValueKey('chat-search-input'),
              controller: controller,
              autofocus: true,
              onChanged: onQueryChanged,
              decoration: InputDecoration(
                hintText: '搜索会话、联系人、聊天记录',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: style.scale(context, 20),
                ),
              ),
            ),
          ),
          if (loading || searching)
            LinearProgressIndicator(
              key: const ValueKey('chat-search-progress'),
              minHeight: style.scale(context, 2),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                error!,
                style: TextStyle(color: style.error(context)),
              ),
            ),
          Expanded(
            child: !hasQuery
                ? _SearchHint(style: style)
                : (loading || searching) && noHit
                ? const Center(child: Text('正在搜索本地内容'))
                : noHit
                ? const Center(child: Text('没有找到相关内容'))
                : ListView(
                    padding: EdgeInsets.only(bottom: style.scale(context, 24)),
                    children: [
                      for (final section in sections)
                        if (section.items.isNotEmpty) ...[
                          _SectionHeader(title: section.title, style: style),
                          for (final item in section.items)
                            ListTile(
                              key: item.key,
                              leading: item.leading,
                              title: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: item.subtitle == null
                                  ? null
                                  : Text(
                                      item.subtitle!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              onTap: item.onTap,
                            ),
                        ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.style});

  final String title;
  final ChatViewStyle style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          color: style.textTertiary(context),
          fontSize: style.scale(context, 12),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint({required this.style});

  final ChatViewStyle style;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: style.scale(context, 32)),
        child: Text(
          '输入关键词，搜索会话、联系人与聊天记录',
          textAlign: TextAlign.center,
          style: TextStyle(color: style.textTertiary(context)),
        ),
      ),
    );
  }
}
