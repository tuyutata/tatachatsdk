import 'package:flutter/widgets.dart';

import '../../call/coordinator.dart';

class ChatCallScope extends InheritedWidget {
  const ChatCallScope({
    super.key,
    required this.coordinator,
    required super.child,
  });

  final ChatCallCoordinator coordinator;

  static ChatCallScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChatCallScope>();

  @override
  bool updateShouldNotify(ChatCallScope oldWidget) =>
      !identical(coordinator, oldWidget.coordinator);
}
