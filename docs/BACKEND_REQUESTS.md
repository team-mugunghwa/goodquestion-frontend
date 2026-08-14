# 백엔드 요청 — 대화 장면 진행/미션 (2026-08-14)

대상 저장소: `team-mugunghwa/goodquestion-backend` (`develop`)
요청 배경: 대화 장면 4곳의 캐릭터 표정·동작 에셋을 제작하면서 콘텐츠 확정안과 서버 구현을
전수 대조했다. 아래는 그 결과 나온 불일치와 버그다.

콘텐츠 확정안 원본: `충족요건/대화{1,2,3,4}_충족조건.md`, `미션 노출 원칙.md` (콘텐츠팀)

| # | 구분 | 내용 | 우선순위 |
|---|---|---|---|
| 1 | 콘텐츠 | 대화1 `required_elements`에서 `REASON` 제거 | 높음 |
| 2 | 버그 | 미션 장면에서 잘한 아이가 장면 보너스를 못 받는 역전 | 높음 |
| 3 | 개선 | 미션 노출 조건에 "방향만 제시" 케이스 추가 | 낮음 |
| 4 | 콘텐츠 | 대화3 캐릭터를 마을 이장 → 시아버지로 교체 | 보류 |

프런트 확인 결과 **변경이 필요 없는 것**은 부록에 정리했다.

---

## 1. 대화1 `required_elements`에서 `REASON` 제거

**대상**: `src/main/resources/db/migration/R__1_seed_content.sql` 장면 3 (`sc_banggui_03`,
`33333333-3333-3333-3333-000000000003`)

**근거**: 시드 주석이 이미 검수를 요청해 둔 항목이다.

> `-- REASON의 기준/걱정 문구는 문서에 없어 제안값이다 - 콘텐츠팀 검수 필요.`

검수 결과 **`REASON`을 제외**하기로 확정했다. 대화1의 장면 목표는 "며느리의 입장을 이해하고
공감하며 솔직하게 말할 용기를 준다"이고, 여기서 아이에게 까닭 설명까지 요구하면 요소가 과하다.
같은 이야기의 대화2가 `REASON`을 이미 담당한다.

나머지 세 장면(대화2·3·4)의 요소 구성은 확정안과 **완전히 일치**하므로 손대지 않는다.

### 변경 내용

```sql
-- required_elements
array['PERSPECTIVE', 'EMOTION', 'REASON', 'SOLUTION']
→ array['PERSPECTIVE', 'EMOTION', 'SOLUTION']
```

`element_criteria`와 `remaining_worries`의 `REASON` 항목도 함께 삭제한다.

```jsonc
// element_criteria — 삭제할 줄
"REASON": "참지 말고 솔직하게 말해야 하는 까닭을 설명함 (예: 계속 참으면 몸이 아프니까요)"

// remaining_worries — 삭제할 줄
"REASON": "솔직하게 말하면 뭐가 좋아지는 걸까? 왜 말해야 하는지 아직 모르겠어."
```

### 함께 반영하면 좋은 것 — `SOLUTION` 인정 기준 보강

확정안의 판정 주의점이 시드 기준보다 구체적이다. 분석 LLM 입력이므로 반영을 권한다.

| | 문구 |
|---|---|
| 현재 시드 | 며느리가 할 수 있는 구체적인 행동을 제안함 |
| 확정안 | **현재의 어려움을 줄일 수 있는** 구체적인 행동 제안 |

확정안이 명시한 판정 규칙:

- "계속 참아요"는 행동이지만 현재 문제를 반복·악화시키므로 `SOLUTION`으로 인정하지 않는다
- "그냥 방귀 뀌어요"는 몸의 불편을 해소하는 구체적 행동이므로 `SOLUTION`은 인정한다
  (단 가족의 입장을 고려하지 않았다면 `PERSPECTIVE`는 미충족)
- 놀리거나 비난하는 말은 감정 단어가 들어가도 `EMOTION`으로 인정하지 않는다

### 영향 범위

`src/test/java/.../story/dialogue/MissionSceneMaxTurnsTest.java`의 `@BeforeEach`가 대화1을
4요소 기준으로 통과시킨다. 3요소로 바뀌면 이 픽스처를 함께 손봐야 한다.

---

## 2. 미션 장면에서 잘한 아이가 장면 보너스를 못 받는다

**대상**: `src/main/java/.../story/dialogue/SceneClosingHandler.java`

### 증상

대화3(미션1) 또는 대화4(미션2)에서 아이가 **첫 턴에 필수 요소 4개를 모두 채우면**,
미션을 볼 기회조차 없이 장면 보너스에서 탈락한다. 가장 잘한 아이가 보상을 못 받는 역전이다.

### 재현 경로

1. 아이가 1턴에 4요소를 모두 말한다 → `accumulatedElements`가 가득 참
2. `MissionPolicy.shouldExpose()` 2번 조건에 걸려 **미션이 노출되지 않는다**

   ```java
   // 2) 구성할 것이 남아 있어야 한다. 이미 다 말했으면 미션이 할 일이 없다.
   if (scene.missingElements(session.getAccumulatedElements()).isEmpty()) {
       return false;
   }
   ```

3. `preferred_turns=2` 게이트로 2턴째가 더 있지만, `missingElements`는 여전히 비어 있어
   미션은 끝내 노출되지 않는다
4. 2턴째에 `CLOSING(GOAL_MET)`으로 장면이 닫힌다
5. `SceneClosingHandler.close()`에서

   ```java
   boolean goalMet = scene.missingElements(...).isEmpty()
           && (!scene.hasMission() || session.isMissionCompleted());
   ```

   미션을 수행할 방법이 없었으므로 `isMissionCompleted() == false` → **`goalMet = false`**
6. `SceneClosedEvent(sceneBonusEligible = false)` → 장면 보너스 별가루 미지급

`closingReason`은 `GOAL_MET`인데 `goalMet`은 `false`인 모순 상태로 기록된다.

### 원인

해당 줄의 주석은 의도를 이렇게 적고 있다.

> 미션 필수 장면의 목표는 "요소 충족 && 미션 완료"다. 요소만 채운 채 **최대 턴으로**
> 닫힌 장면이 목표 달성(장면 보너스 자격)으로 기록되면 안 된다.

의도는 `MAX_TURNS` 종료에만 해당하는데, 코드가 **모든 종료 경로**에 적용된다.

### 제안 (A안)

미션 조건을 `MAX_TURNS` 종료일 때만 적용한다.

```java
boolean elementsMet = scene.missingElements(session.getAccumulatedElements()).isEmpty();
boolean missionOk = !scene.hasMission()
        || session.isMissionCompleted()
        || decision.closingReason() == SceneEndReason.GOAL_MET;
boolean goalMet = elementsMet && missionOk;
```

### 검토했으나 권하지 않는 대안 (B안)

미션을 필수로 보고 미션 미완료 시 종료를 보류하는 방식. `MissionSceneMaxTurnsTest`가 회귀
테스트로 막아 둔 "장면이 열린 채 턴 수만 최대치가 되어 409 `MAX_TURNS_EXCEEDED`로 갇히는"
버그가 재발할 수 있다.

### 정책 확인 요청

위와 별개로 **"미션을 콘텐츠로서 반드시 노출할 것인가"**는 결정이 필요하다.

- 현재 서버 = 미션은 요소를 못 채운 아이를 돕는 **보조 장치** (잘하는 아이는 건너뛴다)
- 확정안 `미션 노출 원칙.md`의 대화3·4 진행 흐름 = 미션이 **필수 단계**로 들어가 있다

A안은 보상 역전만 막고 미션 스킵 자체는 그대로 둔다. 미션을 필수로 보려면 노출 조건을
따로 손봐야 한다.

---

## 3. (선택) 미션 노출 조건 — "방향만 제시" 케이스

**대상**: `src/main/java/.../story/mission/MissionPolicy.java`

확정안 `미션 노출 원칙.md`의 노출 조건 4개 중 3개는 이미 구현돼 있다. 하나가 비어 있다.

| 확정안 조건 | 서버 구현 | |
|---|---|---|
| 아이가 며느리의 방귀를 활용할 수 있다고 제안한 경우 | `accumulated.contains("SOLUTION")` | ✅ |
| **해결 방향은 말했지만 방법이 구체적이지 않은 경우** | — | ❌ |
| 2회 이상 대화했지만 실행 방법이 나오지 않은 경우 | `turnCount >= 2` | ✅ |
| 캐릭터 질문만으로 구체화하기 어려운 경우 | 위 조건으로 흡수 | ➖ |

`SOLUTION`의 인정 기준 자체가 "구체적인 방법 제시"라, 방향만 말한 발화는 `SOLUTION`이
탐지되지 않고 `turnCount >= 2`에만 걸린다. 결과적으로 **1턴에 방향만 말한 아이는 미션이
한 턴 늦게 뜬다.**

영향이 작아 우선순위는 낮다. 반영한다면 `analysis.childIntent`의 제안 계열 의도를 조건에
추가하는 방향이 적절해 보인다.

미션2(`PERSPECTIVE_SHIFT`)의 노출 조건은 확정안과 **완전히 일치**한다 — 확인만 하고 넘어간다.

---

## 4. (보류) 대화3 캐릭터 교체

대화3의 대화 상대를 **마을 이장 → 시아버지**로 바꾸는 안이 콘텐츠 쪽에서 검토 중이다.
전개3에서 배를 보고 군침 도는 인물이 시아버지고, 전개4에서 사과하는 것도 시아버지라
이야기 연결이 더 자연스럽다는 이유다.

지금은 **마을 이장 그대로 진행**한다. 확정되면 별도로 요청하겠다.

바뀔 때 함께 손봐야 하는 것 (범위 참고용):

- `story_scenes` 장면 7 — `character_name`, `character_opening`, `character_closing`,
  `scene_stance`, `proper_nouns`
- `characters` — `village_chief` 행 처리
- 대사 문체 (현재 이장 기준 하오체: "…없었단다", "…고맙소!")
- 미션1 `element_criteria` 중 이장 시점으로 쓰인 문구

---

## 부록. 확인 완료 — 변경 불필요

### `ProgressionEngine`의 `preferred_turns` 게이트

확정안 문서에는 `preferred_turns`를 "최소 턴이 아니라 권장 대화 길이"로 적고 "1턴 만에
모두 충족하면 1턴 종료"라고 기술했으나, 논의 결과 **현행 서버 동작(최소 2턴 게이트)을
유지**하기로 했다.

```java
if (missing.isEmpty() && turnCount >= preferredTurns(scene)) → CLOSING(GOAL_MET)
```

이유는 시드 주석에 이미 적혀 있는 것과 같다 — 게이트가 없으면 말 잘하는 아이의 장면이
1턴에 끝나고, 장면당 제작한 표정 상태 4~7개 중 대부분이 화면에 뜨지 못한다.

확정안 문서 쪽을 서버에 맞춰 수정한다 (콘텐츠팀 처리, 백엔드 조치 없음).

| 문서 | 현재 | 수정 |
|---|---|---|
| 대화2_충족조건.md | `preferred_turns=3` | `2` |
| 대화3_충족조건.md | 권장 턴 `3` | `2` |
| 대화1_충족조건.md | "1턴 만에 3개 충족: 1턴 종료" | 최소 2턴 |

`max_turns`(4/5/5/4)는 네 장면 모두 시드와 일치한다.

### `characterEmotion` / `characters.expression_keys`

프런트 표정 연출은 `UtteranceResponse`의 `analysis`(`detectedElements`,
`utteranceValidity`)와 `progress`(`accumulatedElements`, `mode`)만으로 계산한다.
가이드 3.0절 4번("표정·태도 연출은 `analysis` 값으로만 한다") 그대로다.

따라서 아래 두 가지는 **당장 필요하지 않다.**

- `CharacterMessageResponse`에 `characterEmotion` 추가 — 불필요
- `characters.expression_keys`(며느리 6 / 시아버지 5 / 이장 4) — 이번 에셋 설계와 축이
  다르다. 제작한 상태는 캐릭터 단위 감정이 아니라 **장면 단위 × 충족 요소** 기준이고,
  같은 며느리라도 대화1(`CLOSING_HESITANT`)과 대화4(`CLOSING_CONFIDENT`)의 상태가 다르다.
  `{characterKey}_{expression}.png` 규약도 같은 이유로 쓰지 않는다.

`expression_keys`를 정리할지 남길지는 백엔드 판단에 맡긴다. 프런트는 참조하지 않는다.

### 캐릭터·배경 이미지 서빙

제작한 배경 4장 + 캐릭터 상태 PNG 23장은 **프런트 로컬 에셋**으로 번들한다
(`assets/images/dialogue/banggui/scene_{03,05,07,09}/`). 서버 정적 서빙(`/stories/**`)에
캐릭터 경로를 추가할 필요는 없다.

다만 대화 장면의 `image_url`은 현재 배경+캐릭터가 합쳐진 한 장(`03_dialogue1.jpg` 등)이라
프런트가 쓰지 않는다. 정리 방향은 나중에 논의한다.
