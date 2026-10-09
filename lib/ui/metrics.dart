import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Responsive geometry shared by TataChatSDK's default Flutter UI.
abstract final class ChatUiMetrics {
  static const double designWidth = 411;
  static const double designHeight = 914;
  static const double minimumScale = 0.90;
  static const double maximumScale = 1.10;

  @visibleForTesting
  static double scaleForSize(Size size) => math
      .min(size.width / designWidth, size.height / designHeight)
      .clamp(minimumScale, maximumScale)
      .toDouble();

  static double scaled(BuildContext context, double designValue) =>
      designValue * scaleForSize(MediaQuery.sizeOf(context));
}
