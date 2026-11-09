// lib/audio.dart
// Sound manager with cross-platform safety
import 'package:flutter/foundation.dart';

class GameAudio {
  static bool soundEnabled = true;

  static void play(String type, [double intensity = 1.0]) {
    if (!soundEnabled) return;
    // Log sound trigger in debug mode
    if (kDebugMode) {
      // debugPrint("Audio trigger: $type, intensity: $intensity");
    }
  }

  static void toggleSound() {
    soundEnabled = !soundEnabled;
  }
}
