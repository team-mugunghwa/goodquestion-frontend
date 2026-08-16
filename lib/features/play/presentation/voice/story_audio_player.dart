import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

abstract interface class StoryAudioPlayer {
  Future<void> playUrl(String url);

  /// 지금 재생 중인 오디오의 위치. 파일 하나에 문장 여러 개가 들어 있을 때
  /// 자막을 문장별 실측 시각(audioTimings)에 맞춰 넘기는 데 씁니다.
  ///
  /// **자막 시계는 반드시 이 위치에 묶습니다 — 벽시계 타이머가 아니라.**
  /// [pause] 하면 위치 이벤트가 멈춰 자막도 함께 멈추고, [resume] 하면
  /// 이어집니다. 별도 상태 저장이 필요 없습니다. 위치를 못 주는 구현은
  /// 빈 스트림이면 됩니다 — 자막이 첫 문장에 머물 뿐 소리는 정상입니다.
  Stream<Duration> get onPosition;

  /// 재생 위치를 그대로 둔 채 소리만 멈춥니다. [stop] 과 달리 [playUrl] 의
  /// 기다림을 풀지 않습니다 - 풀어 버리면 부르는 쪽이 "이 문장 다 들었다"로
  /// 보고 다음 문장으로 넘어가 버립니다.
  Future<void> pause();

  /// [pause] 로 멈춘 지점부터 이어 재생합니다.
  Future<void> resume();

  /// [resume] 으로 이어 들을 오디오가 남아 있는지. 없으면 부르는 쪽이 그
  /// 문장을 처음부터 다시 틀어야 합니다.
  bool get canResume;

  /// 소리 끄기/켜기. 재생을 끊지 않고 **볼륨만 0으로 내립니다** - 오디오는
  /// 그대로 흘러가서 문장도 평소 속도로 넘어가고, 다시 켜면 되감기 없이 그
  /// 지점부터 들립니다. 다음 문장을 새로 틀 때도 이 상태가 유지됩니다.
  Future<void> setMuted(bool muted);

  Future<void> stop();

  Future<void> dispose();
}

class DeviceStoryAudioPlayer implements StoryAudioPlayer {
  DeviceStoryAudioPlayer();

  AudioPlayer? _player;

  /// 재생기를 문장마다 새로 만들기 때문에([playUrl]) 위치 스트림도 재생기의
  /// 것을 그대로 노출할 수 없습니다 — 구독자가 옛 재생기에 매달려 있게 됩니다.
  /// 브로드캐스트 컨트롤러 하나로 중계하고, 재생기가 바뀔 때 전달만 갈아 끼웁니다.
  final StreamController<Duration> _positions =
      StreamController<Duration>.broadcast();
  StreamSubscription<Duration>? _positionForward;

  /// 지금 재생 중인 [playUrl] 이 기다리고 있는 완료 신호. [stop] 이 이걸 직접
  /// 완료시킵니다 - audioplayers 의 `stop()` 은 `onPlayerComplete` 를 쏘지
  /// 않아서, 풀어 주지 않으면 소리를 끊어도 호출한 쪽이 45초 타임아웃까지
  /// 매달려 있게 됩니다(= 소리 끄기를 눌러도 이야기가 멈춰 보입니다).
  Completer<void>? _pending;

  /// [_pending] 이 영영 안 풀리는 것을 막는 감시 타이머. 예전에는
  /// `completer.future.timeout(45초)` 였는데, 그러면 일시정지로 멈춰 있어도
  /// 시계가 계속 돌아 45초 뒤에 제멋대로 다음 문장으로 넘어갑니다 - 그래서
  /// 타이머를 따로 들고 [pause] 때 멈췄다가 [resume] 때 다시 겁니다.
  Timer? _watchdog;

  /// [pause] 로 멈춰 있는 상태. [playUrl]·[stop]·[dispose] 가 모두 풉니다.
  bool _paused = false;

  /// 소리 끄기 상태. 재생기를 문장마다 새로 만들기 때문에([playUrl]) 여기에
  /// 들고 있다가 새 재생기에도 그대로 물려 줍니다 - 안 그러면 다음 문장에서
  /// 소리가 되살아납니다.
  bool _muted = false;

  static const Duration _watchdogTimeout = Duration(seconds: 45);

  double get _volume => _muted ? 0 : 1;

  @override
  Stream<Duration> get onPosition => _positions.stream;

  @override
  bool get canResume => _paused && _player != null && _pending != null;

  @override
  Future<void> setMuted(bool muted) async {
    if (_muted == muted) return;
    _muted = muted;
    // 재생은 그대로 둡니다 - 끊으면 재생 위치를 잃고, 다시 켤 때 문장을
    // 처음부터 되감아야 합니다.
    await _player?.setVolume(_volume);
  }

  /// 재생마다 [AudioPlayer]를 새로 만듭니다. 같은 인스턴스를 재사용하면
  /// (`stop()` 후 `play()`) 두 번째 재생부터 `onPlayerComplete`가 아예 안
  /// 오는 경우가 있습니다 - audioplayers 알려진 문제
  /// (bluefireteam/audioplayers#1696, "It does not want to play again after
  /// completed"). 첫 장면 내레이션만 들리고 다음 장면부터 조용해지는 증상과
  /// 정확히 일치합니다.
  @override
  Future<void> playUrl(String url) async {
    final AudioPlayer? previous = _player;
    final AudioPlayer player = AudioPlayer();
    _player = player;
    _paused = false;
    _releasePending();
    if (previous != null) {
      unawaited(previous.dispose());
    }
    final Completer<void> completer = Completer<void>();
    _pending = completer;
    unawaited(_positionForward?.cancel());
    _positionForward = player.onPositionChanged.listen(_positions.add);
    late final StreamSubscription<void> subscription;
    subscription = player.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) completer.complete();
      unawaited(subscription.cancel());
    });
    try {
      // 새 재생기에도 소리 끄기 상태를 물려 줍니다. 소스를 물리기 전에
      // 볼륨을 잡아 두어야 첫 순간에 소리가 새지 않습니다.
      await player.play(_sourceFor(url), volume: _volume);
      _startWatchdog(completer);
      await completer.future;
    } finally {
      _watchdog?.cancel();
      _watchdog = null;
      unawaited(subscription.cancel());
      if (identical(_pending, completer)) _pending = null;
    }
  }

  /// 재생이 끝났다는 신호가 영영 안 오는 경우(플랫폼이 `onPlayerComplete` 를
  /// 안 쏘는 등)에 대비해 정해진 시간 뒤 기다림을 풀어 줍니다. 일시정지
  /// 중에는 돌지 않습니다 - 멈춰 둔 사이에 시간이 차서 다음 문장으로 넘어가면
  /// 안 됩니다.
  void _startWatchdog(Completer<void> completer) {
    _watchdog?.cancel();
    _watchdog = Timer(_watchdogTimeout, () {
      if (identical(_pending, completer)) _releasePending();
    });
  }

  /// 재생을 기다리던 쪽을 "끝났다"로 풀어 줍니다. 소리를 끊었을 때 다음
  /// 문장으로 곧바로 넘어갈 수 있게 하는 장치입니다.
  void _releasePending() {
    final Completer<void>? pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  /// `/api/tts`는 스토리지 없이 `data:audio/mp3;base64,...` 형태의 data URL로
  /// 음성을 돌려줍니다(백엔드가 아직 스토리지를 정하지 않아서입니다).
  /// `UrlSource`는 진짜 네트워크 URL만 받아들여서 data URL을 그대로 넘기면
  /// 소리 없이 조용히 실패합니다 - base64 를 직접 디코드해 [BytesSource]로
  /// 재생합니다. 나중에 서버가 진짜 URL을 내려줘도 이 분기가 그대로 처리합니다.
  Source _sourceFor(String url) {
    // 선택지 문장·재시도 안내는 서버가 아니라 앱에 들어 있는 mp3 입니다
    // (`assets/audio/choices/`). audioplayers 의 [AssetSource] 는 `assets/`
    // 접두어를 **뺀** 경로를 받아 안에서 다시 붙이므로, 그대로 넘기면
    // `assets/assets/...` 를 찾다가 조용히 실패합니다.
    const String assetPrefix = 'assets/';
    if (url.startsWith(assetPrefix)) {
      return AssetSource(url.substring(assetPrefix.length));
    }
    final UriData? data = Uri.parse(url).data;
    if (data != null) {
      return BytesSource(data.contentAsBytes(), mimeType: data.mimeType);
    }
    return UrlSource(url);
  }

  /// 소리를 그 자리에서 멈추되 [_pending] 은 그대로 둡니다 - 이 문장을 아직
  /// 다 듣지 않았기 때문입니다. 풀어 버리면 [playUrl] 을 기다리던 쪽이 다음
  /// 문장으로 넘어갑니다.
  @override
  Future<void> pause() async {
    final AudioPlayer? player = _player;
    if (player == null || _pending == null || _paused) return;
    _paused = true;
    _watchdog?.cancel();
    _watchdog = null;
    await player.pause();
  }

  @override
  Future<void> resume() async {
    final AudioPlayer? player = _player;
    final Completer<void>? pending = _pending;
    if (player == null || pending == null || !_paused) return;
    _paused = false;
    _startWatchdog(pending);
    await player.resume();
  }

  @override
  Future<void> stop() async {
    _paused = false;
    _watchdog?.cancel();
    _watchdog = null;
    _releasePending();
    await _player?.stop();
  }

  @override
  Future<void> dispose() async {
    _paused = false;
    _watchdog?.cancel();
    _watchdog = null;
    _releasePending();
    await _positionForward?.cancel();
    _positionForward = null;
    await _positions.close();
    await _player?.dispose();
    _player = null;
  }
}
