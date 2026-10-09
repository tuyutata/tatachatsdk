import 'package:flutter/material.dart';

typedef ChatSizeScaler = double Function(BuildContext context, double value);

/// Product-independent visual tokens for reusable TataChatSDK screens.
class ChatViewStyle {
  const ChatViewStyle({
    this.backgroundColor,
    this.surfaceColor,
    this.borderColor,
    this.primaryColor,
    this.accentColor,
    this.textPrimaryColor,
    this.textSecondaryColor,
    this.textTertiaryColor,
    this.errorColor,
    this.menuColor = const Color(0xFF66727D),
    this.scaler,
  });

  final Color? backgroundColor;
  final Color? surfaceColor;
  final Color? borderColor;
  final Color? primaryColor;
  final Color? accentColor;
  final Color? textPrimaryColor;
  final Color? textSecondaryColor;
  final Color? textTertiaryColor;
  final Color? errorColor;
  final Color menuColor;
  final ChatSizeScaler? scaler;

  double scale(BuildContext context, double value) =>
      scaler?.call(context, value) ?? value;
  Color background(BuildContext context) =>
      backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;
  Color surface(BuildContext context) =>
      surfaceColor ?? Theme.of(context).colorScheme.surface;
  Color border(BuildContext context) =>
      borderColor ?? Theme.of(context).dividerColor;
  Color primary(BuildContext context) =>
      primaryColor ?? Theme.of(context).colorScheme.primary;
  Color accent(BuildContext context) =>
      accentColor ?? Theme.of(context).colorScheme.primary;
  Color textPrimary(BuildContext context) =>
      textPrimaryColor ?? Theme.of(context).colorScheme.onSurface;
  Color textSecondary(BuildContext context) =>
      textSecondaryColor ??
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.68);
  Color textTertiary(BuildContext context) =>
      textTertiaryColor ??
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
  Color error(BuildContext context) =>
      errorColor ?? Theme.of(context).colorScheme.error;
}
