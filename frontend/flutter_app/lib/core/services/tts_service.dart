// tts_service.dart
// Purpose: Singleton wrapper around flutter_tts for short text-to-speech playback.
//          Used by PhraseScreen for Arabic phrases and scan results for verdict audio.
// Note: flutter_tts is intentionally disabled on web in this app.
//       The device must have the Arabic (ar-SA) language pack installed for
//       Arabic playback to work.
// TODO(next-dev): Show a UI prompt guiding the user to install the Arabic TTS voice pack
//                 if speakArabic() returns false on a non-web platform.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService _instance = TtsService._();
  factory TtsService() => _instance;
  TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  Completer<bool>? _startCompleter;
  String? _lastError;

  String? get lastError => _lastError;

  Future<void> _init() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }
    try {
      _tts.setStartHandler(() {
        _startCompleter?.complete(true);
      });
      _tts.setCancelHandler(() {
        _startCompleter?.complete(false);
      });
      _tts.setErrorHandler((message) {
        _lastError = message?.toString() ?? 'Unknown TTS error';
        _startCompleter?.complete(false);
      });
      await _configureLanguage('en-US');
      await _tts.setSpeechRate(
        defaultTargetPlatform == TargetPlatform.iOS ? 0.45 : 0.7,
      );
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          ],
          IosTextToSpeechAudioMode.spokenAudio,
        );
        await _tts.autoStopSharedSession(false);
        await _tts.setSharedInstance(true);
      }
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _tts.setQueueMode(0);
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[TtsService] Initialization failed: $e');
      _initialized =
          true; // Mark as initialized even on failure to prevent retry loops
    }
  }

  /// Speaks [text]. Returns false on web or if the language pack is missing.
  Future<bool> speak(String text, {String language = 'en-US'}) async {
    if (kIsWeb) {
      debugPrint('[TtsService] Web environment: TTS disabled');
      return false;
    }
    await _init();
    try {
      _lastError = null;
      await _tts.stop();
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _tts.setSharedInstance(true);
      }
      final languageReady = await _configureLanguage(language);
      if (!languageReady) {
        _lastError = 'No TTS voice is available for $language';
        return false;
      }
      final startCompleter = Completer<bool>();
      _startCompleter = startCompleter;
      final speakFuture = _tts.speak(
        text,
        focus: defaultTargetPlatform == TargetPlatform.android,
      );
      final started = await startCompleter.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          _lastError = 'TTS did not start within 2 seconds';
          return false;
        },
      );
      if (!started) {
        await _tts.stop();
        return false;
      }
      await speakFuture.timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          _lastError = 'TTS did not finish within 20 seconds';
          return 0;
        },
      );
      return true;
    } catch (e) {
      debugPrint('[TtsService] Playback failed: $e');
      _lastError = e.toString();
      return false;
    } finally {
      _startCompleter = null;
    }
  }

  /// Speaks [text] in Arabic (ar-SA).
  Future<bool> speakArabic(String text) => speak(text, language: 'ar-SA');

  Future<bool> _configureLanguage(String language) async {
    final candidates = _languageCandidates(language);

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final selectedVoice = await _findInstalledVoice(candidates);
      if (selectedVoice != null) {
        await _tts.setVoice(selectedVoice);
        return true;
      }
    }

    for (final candidate in candidates) {
      try {
        final available = await _tts.isLanguageAvailable(candidate);
        if (available == true || available == 1) {
          await _tts.setLanguage(candidate);
          return true;
        }
      } catch (_) {
        // Some engines do not implement availability checks consistently.
      }
    }

    try {
      await _tts.setLanguage(language);
      return true;
    } catch (e) {
      debugPrint('[TtsService] Language setup failed: $e');
      return false;
    }
  }

  List<String> _languageCandidates(String language) {
    final prefix = language.split('-').first.toLowerCase();
    if (prefix == 'ar') {
      return const ['ar-SA', 'ar', 'ar-001', 'ar-AE', 'ar-EG'];
    }
    if (prefix == 'en') {
      return const ['en-US', 'en', 'en-GB'];
    }
    return [language, prefix];
  }

  Future<Map<String, String>?> _findInstalledVoice(
    List<String> languageCandidates,
  ) async {
    try {
      final voices = await _tts.getVoices;
      if (voices is! List) return null;

      final normalizedCandidates = languageCandidates
          .map((candidate) => candidate.toLowerCase())
          .toList();

      Map<String, dynamic>? fallback;
      for (final voice in voices) {
        if (voice is! Map) continue;
        final locale = voice['locale']?.toString().toLowerCase();
        if (locale == null || locale.isEmpty) continue;

        final exact = normalizedCandidates.contains(locale);
        final sameLanguage = normalizedCandidates.any(
          (candidate) =>
              candidate.length == 2 && locale.startsWith('$candidate-'),
        );
        if (exact || sameLanguage) {
          return _voiceMap(voice);
        }
        if (fallback == null &&
            locale.startsWith(
              '${normalizedCandidates.first.split('-').first}-',
            )) {
          fallback = Map<String, dynamic>.from(voice);
        }
      }

      return fallback == null ? null : _voiceMap(fallback);
    } catch (e) {
      debugPrint('[TtsService] Voice lookup failed: $e');
      return null;
    }
  }

  Map<String, String> _voiceMap(Map<dynamic, dynamic> voice) {
    final result = <String, String>{};
    final identifier = voice['identifier']?.toString();
    final name = voice['name']?.toString();
    final locale = voice['locale']?.toString();
    if (identifier != null && identifier.isNotEmpty) {
      result['identifier'] = identifier;
    }
    if (name != null && name.isNotEmpty) {
      result['name'] = name;
    }
    if (locale != null && locale.isNotEmpty) {
      result['locale'] = locale;
    }
    return result;
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
