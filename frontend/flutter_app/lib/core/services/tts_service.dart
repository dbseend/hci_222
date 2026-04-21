// tts_service.dart
// Purpose: Singleton wrapper around flutter_tts for Arabic text-to-speech playback.
//          Used by PhraseScreen (language tab) to pronounce Arabic negotiation phrases.
// Note: flutter_tts does not support web — all methods are no-ops on kIsWeb.
//       The device must have the Arabic (ar-SA) language pack installed for playback to work.
// TODO(next-dev): Show a UI prompt guiding the user to install the Arabic TTS voice pack
//                 if speakArabic() returns false on a non-web platform.

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService _instance = TtsService._();
  factory TtsService() => _instance;
  TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> _init() async {
    if (_initialized) return;
    // flutter_tts does not support web — skip initialization
    if (kIsWeb) {
      _initialized = true;
      return;
    }
    try {
      await _tts.setLanguage('ar-SA');
      await _tts.setSpeechRate(0.7);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _initialized = true;
    } catch (e) {
      debugPrint('[TtsService] Initialization failed: $e');
      _initialized = true; // Mark as initialized even on failure to prevent retry loops
    }
  }

  /// Speaks [text] in Arabic (ar-SA). Returns false on web or if the language pack is missing.
  Future<bool> speakArabic(String text) async {
    if (kIsWeb) {
      debugPrint('[TtsService] Web environment: TTS not supported');
      return false;
    }
    await _init();
    try {
      await _tts.stop();
      await _tts.setLanguage('ar-SA');
      await _tts.speak(text);
      return true;
    } catch (e) {
      debugPrint('[TtsService] Playback failed: $e');
      return false;
    }
  }

  Future<void> stop() async {
    if (kIsWeb) return;
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('[TtsService] Stop failed: $e');
    }
  }
}
