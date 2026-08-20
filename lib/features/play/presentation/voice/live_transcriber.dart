/// 말하기 후 활동(장면별 질문·답변)에서 "말하는 도중" 글자를 흘리기 위한 자리.
///
/// ## 왜 지금 기기 실시간 인식을 붙이지 않는가
///
/// 목표는 아이가 답을 말하는 **도중에** 글자가 흐르고 낱말 체크가 켜지는 것이다.
/// 그런데 지금 이 앱이 가진 두 갈래 STT 경로 중 어느 쪽도 그 조건을 그대로
/// 만족하지 못한다.
///
/// - 서버 `/api/stt`([MissionVoiceRecorder] 로 녹음해 통째로 올리는 경로)는
///   녹음이 끝난 뒤 한 번에 보내는 배치 방식이라 실시간이 안 된다.
/// - 기기 내장 실시간 인식(`speech_to_text` 패키지)은 **녹음(`record` 패키지)과
///   마이크를 동시에 잡지 못한다.** Android는 패키지 공식 문서가 동시 사용
///   불가라고 명시하고, iOS는 아직 실기 검증이 안 됐다.
///
/// 배포 타겟은 Android + iOS다(`docs/DECISIONS.md` 008/011 — web은 개발
/// 미리보기 전용이지 배포 대상이 아니다). 검증되지 않은 상태로 패키지를
/// 넣어 두 플랫폼 모두에서 조용히 깨지는 위험을 감수하느니, **지금은
/// `speech_to_text` 를 pubspec에 추가하지 않는다.**
///
/// 이 파일은 그래서 구현이 아니라 **자리를 미리 잡아두는 추상화**다.
/// [LiveTranscriber] 인터페이스와 [resolveVoiceMode] 판정 규칙, 그리고
/// 데모/미리보기/테스트에서 실제로 쓰이는 [ScriptedLiveTranscriber] 만
/// 지금 존재한다. iOS 실기 검증이 끝나면 `DeviceLiveTranscriber` 구현
/// 하나와 pubspec 한 줄만 추가하면 [resolveVoiceMode] 가 알아서
/// [RecapVoiceMode.hybrid] 로 격상시키도록 설계했다. 파일 하단의 주석
/// 블록에 그때 알아야 할 것을 적어 두었다.
library;

import 'dart:async';

/// 실시간 인식 중간 결과 한 조각.
///
/// 엔진이 "지금까지 이렇게 들렸다"고 매번 다시 불러 주는 누적 스냅샷이다.
/// 화면은 [text] 를 그대로 덮어써서 보여주면 되고, 델타를 직접 계산할
/// 필요가 없다.
class LiveTranscript {
  const LiveTranscript({required this.text, required this.isFinal});

  /// 지금까지 누적된 인식 결과. 매 조각마다 이전 값을 대체한다(델타 아님).
  final String text;

  /// 엔진이 발화가 끝났다고 판단한 시점이면 true.
  ///
  /// [ScriptedLiveTranscriber] 는 마지막 어절에서 정확히 한 번만 true를
  /// 낸다. 실기기 엔진은 침묵을 감지해 스스로 이 값을 true로 낼 수 있다 —
  /// 그 판단이 왜 녹음 신뢰성보다 우선시되면 안 되는지는 [resolveVoiceMode]
  /// 주석을 참고.
  final bool isFinal;
}

abstract interface class LiveTranscriber {
  /// 권한·엔진 준비까지 마친다. false면 이 기기에서는 실시간을 아예 못 쓴다.
  ///
  /// 호출부는 이 결과를 [resolveVoiceMode] 의 `liveReady` 에 그대로 넘기면
  /// 된다 — false가 나오면 recordOnly로 자동 강등된다.
  Future<bool> initialize();

  /// 실시간 인식을 시작하고 중간 결과 스트림을 연다.
  Stream<LiveTranscript> listen({String localeId = 'ko_KR'});

  /// 인식을 정상 종료한다. 마지막 조각이 아직 안 나왔다면 이 호출로
  /// `isFinal: true` 조각을 마저 흘려보낼 수 있다(구현에 따라 다름).
  Future<void> stop();

  /// 인식을 즉시 취소한다. `stop()` 과 달리 마지막 결과를 기다리지 않는다.
  Future<void> cancel();

  /// 타이머·스트림 컨트롤러 등 내부 리소스를 정리한다.
  Future<void> dispose();
}

/// 이 기기에서 2단계(장면별 질문·답변)가 실제로 어떻게 돌지.
enum RecapVoiceMode {
  /// 녹음(서버 STT용 원본)과 실시간 인식(화면 표시용)을 동시에 돌린다.
  /// 글자는 실시간으로 흐르되, 서버로 보낼 원본은 녹음이 따로 확보한다.
  hybrid,

  /// 녹음 없이 기기 실시간 인식만 쓴다. 서버 STT가 없는 데모 모드가 여기다.
  liveOnly,

  /// 녹음만 하고 끝난 뒤 서버(또는 데모 스크립트)로 텍스트를 얻는다.
  /// 지금 이 앱의 실기기 기본값 — [DeviceLiveTranscriber] 가 아직 없다.
  recordOnly,
}

/// [liveReady], [canRecordWhileListening], [hasServerStt] 세 조건으로
/// [RecapVoiceMode] 를 정한다.
///
/// 판정 순서가 중요하다 — 아래로 갈수록 우선순위가 낮다:
///
/// 1. `liveReady == false` → **recordOnly**. 서버 STT가 없어도 recordOnly를
///    낸다. 녹음 자체는 이 기기에서 언제나 가능하고, 텍스트를 못 얻는 상황은
///    상위 화면(호출부)이 처리할 일이지 이 함수가 판단할 일이 아니다.
/// 2. `liveReady && canRecordWhileListening && hasServerStt` → **hybrid**.
///    두 경로를 동시에 돌릴 수 있고 서버 백업도 있으니 가장 좋은 조합.
/// 3. `liveReady && !hasServerStt` → **liveOnly**. 서버가 없으니 기기
///    실시간 텍스트가 유일한 출처다. 데모 모드가 정확히 이 조합이다.
/// 4. `liveReady && hasServerStt && !canRecordWhileListening` → **recordOnly**
///    (liveOnly가 **아니다**). 이유: 기기 실시간 인식 단독은 침묵이 대략
///    3초쯤 이어지면 엔진이 스스로 발화를 끊는데, 이때 녹음 원본이 없으면
///    끊긴 뒤에 잘려나간 뒷부분을 복구할 방법이 전혀 없다. 이야기를
///    되짚으며 뜸을 들이는 아이의 긴 발화에는 이게 최악의 실패 모드다.
///    서버 STT를 쓸 수 있는 상황에서 그걸 버리고 굳이 실시간을 택할
///    이유가 없다 — 실시간은 녹음 신뢰성 위에 얹는 **덤**이지, 맞바꿀
///    대상이 아니다.
RecapVoiceMode resolveVoiceMode({
  required bool liveReady,
  required bool canRecordWhileListening,
  required bool hasServerStt,
}) {
  if (!liveReady) return RecapVoiceMode.recordOnly;
  if (canRecordWhileListening && hasServerStt) return RecapVoiceMode.hybrid;
  if (!hasServerStt) return RecapVoiceMode.liveOnly;
  return RecapVoiceMode.recordOnly;
}

/// 미리 준 문장을 어절 단위로 흘려보내는 가짜 실시간 인식기.
///
/// **데모 모드·미리보기·위젯 테스트의 실제 경로다.** 실기기 인식이 없는
/// 지금, 2단계 화면이 "말하는 도중 글자가 흐르는" 연출을 보여줄 수 있는
/// 유일한 구현이 이것이다.
class ScriptedLiveTranscriber implements LiveTranscriber {
  ScriptedLiveTranscriber(
    this.script, {
    this.wordInterval = const Duration(milliseconds: 350),
  });

  /// 어절 단위로 흘려보낼 문장. 공백 기준으로 나눈다.
  final String script;

  /// 어절 사이 간격.
  final Duration wordInterval;

  Timer? _timer;
  StreamController<LiveTranscript>? _controller;

  @override
  Future<bool> initialize() async => true;

  @override
  Stream<LiveTranscript> listen({String localeId = 'ko_KR'}) {
    // 이전 스트림이 남아 있다면(재사용 호출) 먼저 정리한다.
    _timer?.cancel();
    unawaited(_controller?.close());

    final List<String> words = script.split(RegExp(r'\s+'))
      ..removeWhere((String w) => w.isEmpty);
    final StreamController<LiveTranscript> controller =
        StreamController<LiveTranscript>();
    _controller = controller;

    if (words.isEmpty) {
      unawaited(controller.close());
      return controller.stream;
    }

    int index = 0;
    // Timer.periodic 대신 매번 새 Timer를 잡는다 — 마지막 어절에서 취소
    // 타이밍을 어절 콜백 안에서 직접 제어하기 위함이다.
    void emitNext() {
      if (controller.isClosed) return;
      index++;
      final String text = words.take(index).join(' ');
      final bool isFinal = index >= words.length;
      controller.add(LiveTranscript(text: text, isFinal: isFinal));
      if (isFinal) {
        unawaited(controller.close());
        return;
      }
      _timer = Timer(wordInterval, emitNext);
    }

    _timer = Timer(wordInterval, emitNext);
    return controller.stream;
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> cancel() async {
    _timer?.cancel();
    _timer = null;
    await _controller?.close();
    _controller = null;
  }

  @override
  Future<void> dispose() async {
    // 위젯 테스트가 "pending timer"로 죽지 않으려면 타이머와 컨트롤러를
    // 반드시 여기서 정리해야 한다 - play_recap_view.dart의 `_saveTimer`가
    // 같은 함정을 경고하고 있다(화면을 나간 뒤 콜백이 불리면 죽는다).
    _timer?.cancel();
    _timer = null;
    await _controller?.close();
    _controller = null;
  }
}

/// 실시간 인식이 아예 준비되지 않은 기기를 나타내는 구현.
///
/// `initialize()`가 항상 false를 반환해 [resolveVoiceMode] 가 recordOnly로
/// 강등시키도록 만든다. `DeviceLiveTranscriber`가 아직 없는 지금, 실기기
/// 경로의 기본값이 바로 이것이다.
class NoopLiveTranscriber implements LiveTranscriber {
  @override
  Future<bool> initialize() async => false;

  @override
  Stream<LiveTranscript> listen({String localeId = 'ko_KR'}) =>
      const Stream<LiveTranscript>.empty();

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}

// ---------------------------------------------------------------------------
// 여기에 speech_to_text 구현이 들어온다 (iOS 실기 검증 완료 후)
// ---------------------------------------------------------------------------
//
// `DeviceLiveTranscriber implements LiveTranscriber` 를 이 자리에 추가하고,
// pubspec.yaml에 `speech_to_text` 한 줄을 넣으면 된다. 붙일 때 반드시
// 알아야 할 것:
//
// 1. `speech_to_text` 7.x부터 `listen(onResult:, partialResults:, localeId:)`
//    같은 개별 파라미터는 **deprecated**다. 대신 `SpeechListenOptions` 객체로
//    묶어서 넘겨야 한다 (`listen(onResult: ..., listenOptions: SpeechListenOptions(partialResults: true, ...))`).
// 2. iOS는 `Info.plist`에 `NSSpeechRecognitionUsageDescription` 이 없으면
//    권한 요청 시점이 아니라 **호출 즉시 크래시**한다. 마이크 권한
//    (`NSMicrophoneUsageDescription`)과는 별개의 키다.
// 3. Android는 `AndroidManifest.xml`의 `<queries>` 블록에
//    `android.speech.RecognitionService` 를 선언해야 한다. Android 11+
//    부터 패키지 가시성 제한 때문에 이게 없으면 인식 서비스를 아예
//    찾지 못한다.
// 4. 붙인 뒤에도 `record`(녹음)와 동시에 못 잡는 문제는 그대로다 — 이
//    구현은 [RecapVoiceMode.liveOnly] 경로(서버 STT 없는 데모 모드 등)에만
//    쓰고, hybrid로 격상하려면 "녹음 중에도 별도 오디오 세션으로 인식이
//    도는지"를 실기기에서 먼저 검증해야 한다. 검증 전까지는
//    `canRecordWhileListening`을 false로 두는 편이 안전하다.
