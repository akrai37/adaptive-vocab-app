import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../l10n.dart';
import '../models/word.dart';

/// Says words aloud with the device's text-to-speech. Recorded audio files can
/// replace this later via [Word.audio].
class Speaker {
  final FlutterTts? _tts;
  String? _voiceLang;

  Speaker() : _tts = FlutterTts() {
    _setUp();
  }

  /// A speaker that does nothing, for tests.
  Speaker.silent() : _tts = null;

  Future<void> _setUp() async {
    try {
      await _tts!.setSpeechRate(0.4); // slower for young children
    } catch (e) {
      debugPrint('TTS unavailable: $e');
    }
  }

  /// Says [word] in [lang] ("en" or "es"), with that language's voice.
  Future<void> say(Word word, String lang) => _speak(word.label(lang), lang);

  /// Says the word, then its fact.
  Future<void> sayWithFact(Word word, String lang) {
    final fact = word.factIn(lang);
    return _speak(
      fact == null ? word.label(lang) : '${word.label(lang)}. $fact',
      lang,
    );
  }

  Future<void> _speak(String text, String lang) async {
    try {
      await _tts?.stop();
      if (_tts != null && _voiceLang != lang) {
        await _tts.setLanguage(ttsLocale[lang] ?? ttsLocale[defaultLanguage]!);
        _voiceLang = lang;
      }
      await _tts?.speak(text);
    } catch (e) {
      debugPrint('TTS failed: $e');
    }
  }
}
