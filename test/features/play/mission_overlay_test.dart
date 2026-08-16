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

      // 생각마다 방금 들은 말을 보여 주고 맞는지 묻습니다. 확인 전에는
      // 다음 생각으로 넘어가지 않습니다.
      expect(find.text('이렇게 들었어요'), findsOneWidget);
      expect(find.text('음성 대답 ${index + 1}'), findsOneWidget);
      expect(
        find.text('${index + 1} / 4 생각 모음'),
        findsNothing,
        reason: '확인 전에 진행 눈금이 먼저 차오르면 안 됩니다',
      );

      await tester.tap(find.text('맞아요'));
      await tester.pumpAndSettle();
      expect(find.text('${index + 1} / 4 생각 모음'), findsOneWidget);
    }

    expect(find.text('내 생각을 이야기에 전하기'), findsOneWidget);
    await tester.tap(find.text('내 생각을 이야기에 전하기'));
    await tester.pump();

    expect(submitted, contains('어떤 도구가 필요할까요?: 음성 대답 1'));
    expect(submitted, contains('어떤 일이 생길까요?: 음성 대답 4'));
  });

  testWidgets('생각마다 다시 말할 수 있고, 확인 전에는 답으로 앉지 않는다', (
    WidgetTester tester,
  ) async {
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
      description: '생각을 말해 보세요.',
      questions: <PlayMissionQuestion>[
        PlayMissionQuestion(key: 'tool', label: '어떤 도구가 필요할까요?'),
      ],
      cards: <PlayMissionCard>[],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MissionOverlay(
          mission: mission,
          recorder: _FakeVoiceRecorder(),
          transcribeAudio: (_) async => '잘못 들린 대답 ${++transcriptIndex}',
          onSubmit: (String value) => submitted = value,
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('눌러서 말하기'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('말하기 완료'));
    await tester.pumpAndSettle();

    expect(find.text('잘못 들린 대답 1'), findsOneWidget);
    expect(
      find.text('내 생각을 이야기에 전하기'),
      findsNothing,
      reason: '확인이 남아 있는 동안에는 전달 버튼이 뜨면 안 됩니다',
    );

    // "다시 말할래요"는 마이크를 한 번 더 누르게 하지 않고 바로 녹음합니다.
    await tester.tap(find.text('다시 말할래요'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('말하기 완료'), findsOneWidget);
    expect(find.text('잘못 들린 대답 1'), findsNothing, reason: '버린 결과가 남으면 안 됩니다');

    await tester.tap(find.bySemanticsLabel('말하기 완료'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('맞아요'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('내 생각을 이야기에 전하기'));
    await tester.pump();

    expect(submitted, '어떤 도구가 필요할까요?: 잘못 들린 대답 2');
  });

  testWidgets('미션 녹음도 상한에 닿으면 자동으로 멈추고 변환을 요청한다', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    int transcribeCalls = 0;
    const PlayMission mission = PlayMission(
      missionId: 'mission_1',
      missionType: PlayMissionType.problemSolving,
      title: '배를 안전하게 받아요',
      description: '생각을 말해 보세요.',
      questions: <PlayMissionQuestion>[
        PlayMissionQuestion(key: 'tool', label: '어떤 도구가 필요할까요?'),
      ],
      cards: <PlayMissionCard>[],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MissionOverlay(
          mission: mission,
          recorder: _FakeVoiceRecorder(),
          transcribeAudio: (_) async {
            transcribeCalls++;
            return '길게 말한 대답';
          },
          onSubmit: (_) {},
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('눌러서 말하기'));
    await tester.pump();
    expect(find.bySemanticsLabel('말하기 완료'), findsOneWidget);

    // 완료를 누르지 않은 채 상한까지 시간이 흐릅니다.
    await tester.pump(const Duration(seconds: maxRecordingSeconds));
    await tester.pumpAndSettle();

    expect(transcribeCalls, 1, reason: '상한에서 자동으로 멈추고 변환을 요청해야 합니다');
    expect(find.text('길게 말한 대답'), findsOneWidget);
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
