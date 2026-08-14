import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

abstract interface class StoryAudioPlayer {
  Future<void> playUrl(String url);

  Future<void> stop();

  Future<void> dispose();
}

class DeviceStoryAudioPlayer implements StoryAudioPlayer {
  DeviceStoryAudioPlayer() : _player = AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> playUrl(String url) async {
    await _player.stop();
    final Completer<void> completer = Completer<void>();
    late final StreamSubscription<void> subscription;
    subscription = _player.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) completer.complete();
      unawaited(subscription.cancel());
    });
    await _player.play(UrlSource(url));
    await completer.future.timeout(
      const Duration(seconds: 45),
      onTimeout: () => unawaited(subscription.cancel()),
    );
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
