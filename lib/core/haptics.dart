import 'package:flutter/services.dart';

/// Tiny wrapper so haptics can be turned off in one place.
abstract final class Haptics {
  static bool enabled = true;

  static void tap() {
    if (enabled) HapticFeedback.selectionClick();
  }

  static void press() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void bump() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  static void success() {
    if (enabled) HapticFeedback.lightImpact();
  }
}
