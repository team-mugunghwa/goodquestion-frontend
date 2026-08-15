import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// 기기에 내장된 목소리로 글자를 읽어 줍니다.
///
/// ## 이건 임시입니다
///
/// 서버 TTS 가 붙기 전까지만 씁니다. 캐릭터 목소리가 아니라 **기기 기본
/// 목소리**라 톤이 다릅니다 — 이야기 낭독에 쓰지 말고, 단어처럼 짧은 것만
/// 읽히세요. → `docs/DECISIONS.md` 019
///
/// ## 목소리가 없는 기기가 있습니다
///
/// 한국어 목소리가 깔려 있지 않으면 **아무 소리도 나지 않습니다.** 그래서
/// [available] 을 먼저 물어보고, 없으면 화면에서 버튼을 아예 숨깁니다 —
/// 눌러도 반응 없는 버튼은 아이에게 고장으로 읽힙니다.
///
/// 준비는 [init] 에서 한 번만 하고, 실패해도 **앱을 막지 않습니다.**
/// 소리가 없다고 화면이 안 뜨면 곤란합니다.
class SpeechService {
  SpeechService._();

  /// 앱 전체가 하나를 씁니다 — 소리는 한 번에 하나만 나야 합니다.
  ///
  /// `getIt` 에 넣지 않았습니다. `SpeakerButton` 은 위젯 테스트에서 DI 없이
  /// 그려지는데, 거기서 서비스 로케이터를 찾으면 테스트가 깨집니다.
  static final SpeechService instance = SpeechService._();

  static const String _language = 'ko-KR';

  /// 완료 신호가 오지 않는 플랫폼 대비 상한. 글자 수에 비례해 잡습니다.
  static const Duration _minCap = Duration(seconds: 2);
  static const Duration _maxCap = Duration(seconds: 15);
  static const Duration _perChar = Duration(milliseconds: 300);

  /// [init] 전에는 만들지 않습니다 — 위젯 테스트에서 플러그인 채널을
  /// 건드리지 않기 위해서입니다.
  FlutterTts? _tts;

  bool _initialized = false;
  bool _available = false;
  Completer<void>? _turn;

  /// 한국어를 읽어 줄 수 있는가. [init] 전에는 항상 `false` 입니다.
  bool get available => _available;

  /// 앱 시작 때 한 번 부릅니다. 두 번째부터는 아무 일도 하지 않습니다.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final FlutterTts tts = FlutterTts();
      _tts = tts;
      tts.setCompletionHandler(_finish);
      tts.setCancelHandler(_finish);
      tts.setErrorHandler((dynamic message) {
        debugPrint('읽어 주기 실패: $message');
        _finish();
      });
      _available = await _hasKorean(tts);
      if (_available) await tts.setLanguage(_language);
    } on Object catch (e) {
      // 플러그인이 없는 플랫폼(위젯 테스트·일부 데스크톱)에서는 조용히 꺼 둡니다.
      debugPrint('음성을 준비하지 못했습니다 — 스피커 버튼을 숨깁니다: $e');
      _available = false;
    }
  }

  /// 웹은 목소리 목록이 **비동기로** 채워집니다. 첫 조회가 비어 있다고 해서
  /// 목소리가 없는 게 아니라, 몇 번 더 물어봅니다.
  Future<bool> _hasKorean(FlutterTts tts) async {
    for (int i = 0; i < 5; i++) {
      if (await tts.isLanguageAvailable(_language) == true) return true;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return false;
  }

  /// [text] 를 읽어 주고, 다 읽을 때까지 기다립니다.
  ///
  /// 읽는 중에 또 부르면 **끊고 새로 읽습니다** — 아이가 버튼을 다시 누르는 건
  /// "멈춰"가 아니라 "한 번 더"입니다. (`SpeakerButton` 과 같은 규칙)
  Future<void> speak(String text) async {
    final FlutterTts? tts = _tts;
    final String body = text.trim();
    if (!_available || tts == null || body.isEmpty) return;

    await stop();
    final Completer<void> turn = Completer<void>();
    _turn = turn;
    try {
      await tts.speak(body);
    } on Object catch (e) {
      debugPrint('읽어 주기 실패: $e');
      _finish();
      return;
    }
    await turn.future.timeout(_capFor(body), onTimeout: _finish);
  }

  Future<void> stop() async {
    final FlutterTts? tts = _tts;
    if (tts == null) return;
    try {
      await tts.stop();
    } on Object catch (_) {
      // 멈추지 못해도 다음 재생에는 영향이 없습니다.
    }
    _finish();
  }

  void _finish() {
    final Completer<void>? turn = _turn;
    _turn = null;
    if (turn != null && !turn.isCompleted) turn.complete();
  }

  Duration _capFor(String text) {
    final Duration guess = _perChar * text.length;
    if (guess < _minCap) return _minCap;
    if (guess > _maxCap) return _maxCap;
    return guess;
  }
}
