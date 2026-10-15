import 'package:flutter/services.dart';

/// Top-level haptic helper reused throughout the app. No class prefix needed.
void vibrateNow() {
  HapticFeedback.lightImpact();
}