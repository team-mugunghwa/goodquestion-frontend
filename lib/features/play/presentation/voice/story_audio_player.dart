import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

abstract interface class StoryAudioPlayer {
  Future<void> playUrl(String url);

  Future<void> stop();

  Future<void> dispose();
}

class DeviceStoryAudioPlayer implements StoryAudioPlayer {
  DeviceStoryAudioPlayer();

  AudioPlayer? _player;

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
    if (previous != null) {
      unawaited(previous.dispose());
    }
    final Completer<void> completer = Completer<void>();
    late final StreamSubscription<void> subscription;
    subscription = player.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) completer.complete();
      unawaited(subscription.cancel());
    });
    await player.play(_sourceFor(url));
    await completer.future.timeout(
      const Duration(seconds: 45),
      onTimeout: () => unawaited(subscription.cancel()),
    );
  }

  /// `/api/tts`는 스토리지 없이 `data:audio/mp3;base64,...` 형태의 data URL로
  /// 음성을 돌려줍니다(백엔드가 아직 스토리지를 정하지 않아서입니다).
  /// `UrlSource`는 진짜 네트워크 URL만 받아들여서 data URL을 그대로 넘기면
  /// 소리 없이 조용히 실패합니다 - base64 를 직접 디코드해 [BytesSource]로
  /// 재생합니다. 나중에 서버가 진짜 URL을 내려줘도 이 분기가 그대로 처리합니다.
  Source _sourceFor(String url) {
    final UriData? data = Uri.parse(url).data;
    if (data != null) {
      return BytesSource(data.contentAsBytes(), mimeType: data.mimeType);
    }
    return UrlSource(url);
  }

  @override
  Future<void> stop() async {
    await _player?.stop();
  }

  @override
  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}
