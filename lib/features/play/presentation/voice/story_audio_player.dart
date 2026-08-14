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
  AudioPlayer get _devicePlayer => _player ??= AudioPlayer();

  @override
  Future<void> playUrl(String url) async {
    await _devicePlayer.stop();
    final Completer<void> completer = Completer<void>();
    late final StreamSubscription<void> subscription;
    subscription = _devicePlayer.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) completer.complete();
      unawaited(subscription.cancel());
    });
    await _devicePlayer.play(UrlSource(url));
    await completer.future.timeout(
      const Duration(seconds: 45),
      onTimeout: () => unawaited(subscription.cancel()),
    );
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
