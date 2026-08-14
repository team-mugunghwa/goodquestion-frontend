import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/features/play/domain/entities/play_session.dart';
import 'package:goodquestion/features/play/presentation/voice/mission_voice_recorder.dart';
import 'package:goodquestion/features/play/presentation/widgets/mission_overlay.dart';

void main() {
  testWidgets('문제 해결 미션은 키보드 없이 네 음성 답변을 모아 전달한다', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? submitted;
    int transcriptIndex = 0;
    const PlayMission mission = PlayMission(
      missionId: 'mission_1',
      missionType: PlayMissionType.problemSolving,
      title: '배를 안전하게 받아요',
      description: '네 가지 생각을 모아 해결 방법을 만들어 보세요.',
      questions: <PlayMissionQuestion>[
        PlayMissionQuestion(key: 'tool', label: '어떤 도구가 필요할까요?'),
        PlayMissionQuestion(key: 'safety', label: '어떻게 안전하게 할까요?'),
        PlayMissionQuestion(key: 'request', label: '누구에게 도움을 청할까요?'),
        PlayMissionQuestion(key: 'expectedResult', label: '어떤 일이 생길까요?'),
      ],
      cards: <PlayMissionCard>[],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MissionOverlay(
          mission: mission,
          recorder: _FakeVoiceRecorder(),
          transcribeAudio: (_) async => '음성 대답 ${++transcriptIndex}',
          onSubmit: (String value) => submitted = value,
        ),
      ),
    );

    expect(find.text('이야기 속 생각 미션'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.bySemanticsLabel('눌러서 말하기'), findsOneWidget);

    for (int index = 0; index < 4; index++) {
      await tester.tap(find.bySemanticsLabel('눌러서 말하기'));
      await tester.pump();
      expect(find.bySemanticsLabel('말하기 완료'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('말하기 완료'));
      await tester.pumpAndSettle();
    }

    expect(find.text('내 생각을 이야기에 전하기'), findsOneWidget);
    await tester.tap(find.text('내 생각을 이야기에 전하기'));
    await tester.pump();

    expect(submitted, contains('어떤 도구가 필요할까요?: 음성 대답 1'));
    expect(submitted, contains('어떤 일이 생길까요?: 음성 대답 4'));
  });

  testWidgets('관점 전환 미션은 대표 이미지와 서버 문장 틀을 표시한다', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const PlayMission mission = PlayMission(
      missionId: 'mission_2',
      missionType: PlayMissionType.perspectiveShift,
      title: '친구의 힘을 찾아요',
      description: '서로 다른 친구의 장점을 찾아보세요.',
      questions: <PlayMissionQuestion>[],
      cards: <PlayMissionCard>[
        PlayMissionCard(
          key: 'loud',
          label: '목소리가 큰 친구',
          template: '목소리가 큰 친구는 ___ 할 수 있어요.',
        ),
        PlayMissionCard(key: 'talkative', label: '말이 많은 친구'),
        PlayMissionCard(key: 'shy', label: '겁이 많은 친구'),
        PlayMissionCard(key: 'playful', label: '장난을 많이 치는 친구'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MissionOverlay(
          mission: mission,
          recorder: _FakeVoiceRecorder(),
          transcribeAudio: (_) async => '멋진 장점이에요',
          onSubmit: (_) {},
        ),
      ),
    );

    expect(find.text('목소리가 큰 친구'), findsOneWidget);
    expect(find.text('목소리가 큰 친구는 ___ 할 수 있어요.'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName.endsWith(
              'banggui_mission_2.png',
            ),
      ),
      findsOneWidget,
    );
  });
}

class _FakeVoiceRecorder implements MissionVoiceRecorder {
  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> start() async => true;

  @override
  Future<Uint8List?> stop() async => Uint8List.fromList(<int>[1, 2, 3]);
}
