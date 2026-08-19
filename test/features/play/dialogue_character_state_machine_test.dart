import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/features/play/domain/entities/play_session.dart';
import 'package:goodquestion/features/play/presentation/character/dialogue_character_manifest.dart';
import 'package:goodquestion/features/play/presentation/character/dialogue_character_state_machine.dart';

/// 실제 번들 매니페스트를 그대로 읽는다. 테스트용 JSON을 따로 두면 확정안이 바뀌었을 때
/// 테스트만 통과하고 화면이 깨진다.
DialogueCharacterManifest _manifest() => DialogueCharacterManifest.parse(
  File('assets/images/dialogue/banggui/states.json').readAsStringSync(),
);

const String _scene03 = '33333333-3333-3333-3333-000000000003';
const String _scene05 = '33333333-3333-3333-3333-000000000005';
const String _scene07 = '33333333-3333-3333-3333-000000000007';
const String _scene09 = '33333333-3333-3333-3333-000000000009';

PlayTurnResult _turn({
  List<String> accumulated = const <String>[],
  List<String> newElements = const <String>[],
  List<String> detected = const <String>[],
  String validity = 'VALID',
  PlayResponseMode mode = PlayResponseMode.normal,
  PlaySceneTransition? transition,
}) => PlayTurnResult(
  characterText: '...',
  characterAudioUrl: null,
  mission: null,
  sceneTransition: transition,
  analysis: PlayAnalysis(
    detectedElements: detected,
    utteranceValidity: validity,
  ),
  progress: PlayProgress(
    mode: mode,
    accumulatedElements: accumulated,
    newElements: newElements,
  ),
);

DialogueCharacterStateMachine _machineFor(String sceneId) {
  final DialogueCharacterManifest manifest = _manifest();
  return DialogueCharacterStateMachine(
    manifest.sceneFor(sceneId: sceneId)!,
    manifest,
  );
}

/// 서버가 자유 대화에서 내려주는 감정 값. 백엔드 `CharacterEmotion` 6종과
/// 같아야 한다 - 한쪽만 바뀌면 표정이 조용히 멈춘다.
const List<String> _serverEmotions = <String>[
  'NEUTRAL',
  'HAPPY',
  'SAD',
  'WORRIED',
  'SURPRISED',
  'RELIEVED',
];

void main() {
  _newElementsTests();

  group('자유 대화 감정 매핑', () {
    test('감정 표는 서버 6종만 쓰고, 실재하는 표정만 가리킨다', () {
      // 서버는 `HAPPY` 를 주고 표정 키는 `hopeful` 이다. 이 표가 없으면 둘이
      // 한 번도 만나지 못해 자유 대화 표정이 끝까지 안 바뀐다.
      final DialogueCharacterManifest manifest = _manifest();

      for (final String sceneId in <String>[
        _scene03,
        _scene05,
        _scene07,
        _scene09,
      ]) {
        final DialogueSceneStates scene = manifest.sceneFor(sceneId: sceneId)!;
        expect(
          scene.emotionToState,
          isNotEmpty,
          reason: '${scene.label}: 감정 표가 비면 자유 대화에서 표정이 멈춘다',
        );
        for (final MapEntry<String, String> entry
            in scene.emotionToState.entries) {
          expect(
            _serverEmotions,
            contains(entry.key),
            reason: '${scene.label}: 서버가 주지 않는 감정 값이다',
          );
          expect(
            scene.assetOf(entry.value),
            isNotNull,
            reason: '${scene.label}: ${entry.key} 가 없는 표정을 가리킨다',
          );
        }
      }
    });

    test('어느 인물이든 기쁨과 중립은 표정이 있다', () {
      // 자유 대화에서 가장 흔한 두 감정이다. 이것마저 비면 "표정이 안 바뀐다"는
      // 신고가 그대로 돌아온다.
      final DialogueCharacterManifest manifest = _manifest();
      for (final String sceneId in <String>[
        _scene03,
        _scene05,
        _scene07,
        _scene09,
      ]) {
        final DialogueSceneStates scene = manifest.sceneFor(sceneId: sceneId)!;
        expect(
          scene.stateForEmotion('NEUTRAL'),
          isNotNull,
          reason: scene.label,
        );
        expect(scene.stateForEmotion('HAPPY'), isNotNull, reason: scene.label);
      }
    });

    test('모르는 감정은 표정을 바꾸지 않는다', () {
      final DialogueSceneStates scene = _manifest().sceneFor(
        sceneId: _scene03,
      )!;
      expect(scene.stateForEmotion('ANGRY'), isNull);
      expect(scene.stateForEmotion(null), isNull);
      expect(scene.stateForEmotion(''), isNull);
    });

    test('상태 키를 그대로 보내던 옛 서버와도 호환한다', () {
      final DialogueSceneStates scene = _manifest().sceneFor(
        sceneId: _scene03,
      )!;
      expect(scene.stateForEmotion('comforted'), 'comforted');
    });
  });

  group('매니페스트', () {
    test('네 장면이 모두 있고 에셋 파일이 실재한다', () {
      final Map<String, dynamic> json =
          jsonDecode(
                File(
                  'assets/images/dialogue/banggui/states.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final DialogueCharacterManifest manifest = _manifest();

      for (final String sceneId in <String>[
        _scene03,
        _scene05,
        _scene07,
        _scene09,
      ]) {
        final DialogueSceneStates scene = manifest.sceneFor(sceneId: sceneId)!;
        for (final String asset in scene.allAssets) {
          expect(File(asset).existsSync(), isTrue, reason: '없는 에셋: $asset');
        }
      }
      expect((json['scenes'] as Map<String, dynamic>).length, 4);
    });

    test('장면 UUID를 못 찾으면 순번으로 되짚는다', () {
      final DialogueCharacterManifest manifest = _manifest();
      expect(manifest.sceneFor(sceneId: '없는-id', sceneOrder: 7)?.label, '대화3');
      expect(manifest.sceneFor(sceneId: '없는-id', sceneOrder: 99), isNull);
    });
  });

  group('상태 판정', () {
    test('첫 상태는 opening이다', () {
      expect(_machineFor(_scene05).current, 'opening');
    });

    test('새로 충족된 요소가 그 요소의 표정으로 옮긴다', () {
      final DialogueCharacterStateMachine m = _machineFor(_scene05);
      final DialogueStateTransition? t = m.apply(
        _turn(accumulated: <String>['EMPATHY'], detected: <String>['EMPATHY']),
      );
      expect(t?.state, 'softened');
      expect(m.current, 'softened');
    });

    test('대화2의 PERSPECTIVE와 REASON은 같은 considering으로 묶인다', () {
      final DialogueCharacterStateMachine m = _machineFor(_scene05);
      expect(
        m.apply(_turn(accumulated: <String>['PERSPECTIVE']))?.state,
        'considering',
      );
      expect(
        m.apply(_turn(accumulated: <String>['PERSPECTIVE', 'REASON']))?.state,
        isNull,
        reason: 'REASON도 considering이라 표정이 그대로면 전환이 없다',
      );
    });

    test('이미 누적된 요소가 다시 와도 표정을 바꾸지 않는다', () {
      final DialogueCharacterStateMachine m = _machineFor(_scene05);
      m.apply(_turn(accumulated: <String>['EMPATHY']));
      final DialogueStateTransition? again = m.apply(
        _turn(accumulated: <String>['EMPATHY']),
      );
      expect(again, isNull);
      expect(m.current, 'softened');
    });

    test('한 턴에 여러 요소가 오면 statePriority 앞쪽이 이긴다', () {
      // 대화3 우선순위: safety_planning > result_hopeful > feasibility_considering > idea_interested
      final DialogueCharacterStateMachine m = _machineFor(_scene07);
      expect(
        m
            .apply(
              _turn(accumulated: <String>['SOLUTION', 'REASON', 'REQUEST']),
            )
            ?.state,
        'safety_planning',
      );

      final DialogueCharacterStateMachine m2 = _machineFor(_scene07);
      expect(
        m2.apply(_turn(accumulated: <String>['SOLUTION', 'REASON']))?.state,
        'feasibility_considering',
        reason: 'REQUEST가 없으면 그다음 순위인 REASON 쪽이 뜬다',
      );
    });

    test('요소를 다 채워도 CLOSING 신호가 없으면 닫지 않는다', () {
      // 서버가 preferred_turns(최소 2턴) 게이트를 두고 있어 1턴에 다 채워도 NORMAL로 온다.
      final DialogueCharacterStateMachine m = _machineFor(_scene07);
      final DialogueStateTransition? t = m.apply(
        _turn(accumulated: <String>['SOLUTION', 'REASON', 'REQUEST', 'RESULT']),
      );
      expect(t?.state, 'safety_planning');
      expect(t?.via, isNull);
      expect(m.current, isNot('closing'));
    });

    test('놀림·주제 이탈·불명확은 당황 표정으로 간다', () {
      final DialogueCharacterStateMachine m = _machineFor(_scene07);
      for (final String validity in <String>[
        'PLAYFUL',
        'OFF_TOPIC',
        'UNCLEAR',
      ]) {
        m.moveTo('opening');
        expect(
          m.apply(_turn(validity: validity))?.state,
          'hurt_confused',
          reason: validity,
        );
      }
    });

    test('SHORT는 당황 표정 대상이 아니다', () {
      final DialogueCharacterStateMachine m = _machineFor(_scene07);
      expect(m.apply(_turn(validity: 'SHORT')), isNull);
      expect(m.current, 'opening');
    });

    test('대화4는 당황 표정이 없어 현재 상태를 유지한다', () {
      final DialogueCharacterStateMachine m = _machineFor(_scene09);
      m.apply(_turn(accumulated: <String>['PERSPECTIVE']));
      expect(m.current, 'reassured');
      expect(m.apply(_turn(validity: 'PLAYFUL')), isNull);
      expect(m.current, 'reassured');
    });

    test('진전이 없는 턴은 표정을 유지한다', () {
      final DialogueCharacterStateMachine m = _machineFor(_scene05);
      m.apply(_turn(accumulated: <String>['EMPATHY']));
      expect(
        m.apply(_turn(accumulated: <String>['EMPATHY'], validity: 'VALID')),
        isNull,
      );
      expect(m.current, 'softened');
    });
  });

  group('종료 턴', () {
    test('CLOSING이면 closingVia를 거쳐 closing으로 간다', () {
      final DialogueCharacterStateMachine m = _machineFor(_scene05);
      final DialogueStateTransition? t = m.apply(
        _turn(
          accumulated: <String>['PERSPECTIVE', 'EMPATHY', 'REASON', 'REQUEST'],
          mode: PlayResponseMode.closing,
        ),
      );
      expect(t?.state, 'closing');
      expect(t?.via, 'softened');
    });

    test('sceneTransition만 와도 닫는다', () {
      final DialogueCharacterStateMachine m = _machineFor(_scene07);
      final DialogueStateTransition? t = m.apply(
        _turn(
          transition: const PlaySceneTransition(
            next: PlayTransitionTarget.scene,
          ),
        ),
      );
      expect(t?.state, 'closing');
      expect(t?.via, 'result_hopeful');
    });

    test('이미 closingVia 표정이면 거치지 않고 바로 닫는다', () {
      final DialogueCharacterStateMachine m = _machineFor(_scene05);
      m.apply(_turn(accumulated: <String>['EMPATHY']));
      expect(m.current, 'softened');
      final DialogueStateTransition? t = m.apply(
        _turn(
          accumulated: <String>['EMPATHY', 'REQUEST'],
          mode: PlayResponseMode.closing,
        ),
      );
      expect(t?.state, 'closing');
      expect(t?.via, isNull);
    });
  });

  group('이어하기', () {
    test('primeAccumulated로 넘긴 요소는 새 충족으로 치지 않는다', () {
      final DialogueCharacterStateMachine m = _machineFor(_scene05);
      m.primeAccumulated(<String>['EMPATHY', 'PERSPECTIVE']);
      expect(
        m.apply(_turn(accumulated: <String>['EMPATHY', 'PERSPECTIVE'])),
        isNull,
      );
      expect(m.current, 'opening');
      expect(
        m
            .apply(
              _turn(accumulated: <String>['EMPATHY', 'PERSPECTIVE', 'REQUEST']),
            )
            ?.state,
        'reluctant',
      );
    });

    test('reset하면 opening으로 돌아간다', () {
      final DialogueCharacterStateMachine m = _machineFor(_scene05);
      m.apply(_turn(accumulated: <String>['EMPATHY']));
      m.reset();
      expect(m.current, 'opening');
      expect(
        m.apply(_turn(accumulated: <String>['EMPATHY']))?.state,
        'softened',
      );
    });
  });

  group('서버 값이 비어 올 때', () {
    test('progress가 없으면 detectedElements로 판정한다', () {
      final DialogueCharacterStateMachine m = _machineFor(_scene05);
      final DialogueStateTransition? t = m.apply(
        const PlayTurnResult(
          characterText: '...',
          characterAudioUrl: null,
          mission: null,
          sceneTransition: null,
          analysis: PlayAnalysis(
            detectedElements: <String>['EMPATHY'],
            utteranceValidity: 'VALID',
          ),
        ),
      );
      expect(t?.state, 'softened');
    });

    test('analysis와 progress가 모두 없으면 표정을 바꾸지 않는다', () {
      final DialogueCharacterStateMachine m = _machineFor(_scene05);
      expect(
        m.apply(
          const PlayTurnResult(
            characterText: '...',
            characterAudioUrl: null,
            mission: null,
            sceneTransition: null,
          ),
        ),
        isNull,
      );
    });

    test('장면에 없는 요소가 와도 무시한다', () {
      final DialogueCharacterStateMachine m = _machineFor(_scene05);
      // 대화1에서 뺀 REASON이 대화3에 오는 식의 어긋남을 흘려보낸다.
      expect(
        m.apply(_turn(accumulated: <String>['DECISION', 'RESULT'])),
        isNull,
      );
      expect(m.current, 'opening');
    });
  });
}

/// 서버가 표정 고르라고 따로 주는 `progress.newElements` 를 쓰는지.
///
/// 프런트가 누적을 직접 diff 하던 길은 **이어하기에서 어긋난다** - 직전 누적을
/// 모르는 채로 들어와 첫 턴에 누적 전체가 "이번에 새로 통한 것"이 된다.
void _newElementsTests() {
  group('서버가 알려 준 이번 턴 요소', () {
    test('newElements 가 있으면 그것만 본다', () {
      final DialogueCharacterStateMachine machine = _machineFor(_scene03);

      // 누적에는 EMOTION 도 있지만 이번 턴에 새로 통한 것은 PERSPECTIVE 뿐이다.
      final DialogueStateTransition? transition = machine.apply(
        _turn(
          accumulated: <String>['EMOTION', 'PERSPECTIVE'],
          newElements: <String>['PERSPECTIVE'],
        ),
      );

      expect(transition?.state, 'considering');
    });

    test('이어하기로 들어와도 이번 턴 요소만 반영한다', () {
      // 직전 누적을 모르는 상태(primeAccumulated 없이 시작)에서도, 서버가
      // 이번 턴 요소를 알려 주므로 엉뚱한 표정으로 튀지 않는다.
      final DialogueCharacterStateMachine machine = _machineFor(_scene03);

      final DialogueStateTransition? transition = machine.apply(
        _turn(
          accumulated: <String>['EMOTION', 'PERSPECTIVE', 'SOLUTION'],
          newElements: <String>['EMOTION'],
        ),
      );

      expect(
        transition?.state,
        'comforted',
        reason: '누적을 직접 diff 하면 우선순위가 앞선 hopeful 로 잘못 간다',
      );
    });

    test('newElements 가 없는 옛 응답은 누적 diff 로 되돌아간다', () {
      final DialogueCharacterStateMachine machine = _machineFor(_scene03);

      expect(
        machine.apply(_turn(accumulated: <String>['EMOTION']))?.state,
        'comforted',
      );
    });
  });
}
