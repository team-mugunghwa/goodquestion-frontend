# 백엔드 요청 — 완주 여부 한 필드 (후속 자유 대화 재진입) (2026-08-19)

대상 저장소: `team-mugunghwa/goodquestion-backend`
관련 API: `docs/API.md` §2.10-1 후속 자유 대화 · §2.4 이야기 상세

**요청은 하나다.** `StoryDetailResponse` 에 **이 아이가 이 이야기를 완주했는지**를
담은 필드를 하나 추가해 달라.

| # | 구분 | 내용 | 상태 |
|---|---|---|---|
| 1 | 스키마 | `StoryDetailResponse.completed: boolean` (또는 `lastCompletedAt`) | 요청 |
| 2 | 스키마 | `ReportListResponse` 에 `storyId` 추가 | 요청 |

**2번이 선택 사항이 아니게 됐다.** 이야기 **목록**에도 완주 도장을 찍기로
하면서, 목록 여덟 편의 완주 여부를 리포트 제목으로 맞추고 있다. 제목 매칭은
같은 제목의 이야기가 둘 생기는 순간 조용히 틀린다. → 4절

프런트는 **이 필드 없이도 동작하게 이미 붙여 뒀다.** 아래 2절의 우회를 쓰고 있고,
필드가 오면 그 우회를 지운다. 급한 요청이 아니라 **정리 요청**이다.

---

## 0. 왜 필요한가

후속 자유 대화(§2.10-1)는 완주한 이야기의 인물과 이어서 말하는 기능이다.
그런데 앱 안에서 이 기능으로 들어가는 문이 **완주 직후 완료 화면 하나뿐**이었다.
그 화면은 재생 라우트 아래 중첩이라 홈으로 나가는 순간 다시 못 온다.

결과: **어제 완주한 이야기의 친구에게는 앱 안에 도달할 길이 아예 없다.**
아이 입장에서는 이야기를 끝내면 친구가 사라진 것처럼 보인다.

서버 쪽은 아무 문제가 없다. 자유 대화는 세션과 무관하고 `childId` + `storyId`
둘로 다시 열리며, `FreeTalkCharacterResponse.lastTalkedAt` 이 있다는 것 자체가
**재방문을 전제로 설계됐다**는 뜻이다. 없는 것은 문 하나였다.

그래서 이야기 상세 화면 하단에 두 번째 문을 붙였다.
→ `lib/features/story/presentation/views/story_detail_view.dart` `_StartBar`

## 1. 막힌 곳 — 완주 여부를 클라이언트가 알 수 없다

이 버튼은 **완주한 이야기에만** 떠야 한다. 안 들은 이야기에서 누르면 404 로
돌려세워지는데, 아이에게 눌러도 안 되는 버튼을 보여 주는 셈이다.

그런데 완주 여부를 알 수 있는 응답이 하나도 없다.

| 후보 | 왜 못 쓰나 |
|---|---|
| `GET /api/stories/{storyId}` → `StoryDetailResponse` | 완주 관련 필드가 없다 |
| `GET /api/children/{childId}/home` → `activity.completedStories` | **개수**만 있고 어느 이야기인지 없다 |
| `GET /api/children/{childId}/reports` → `ReportListResponse` | `storyTitle` 은 있는데 **`storyId` 가 없어** 이야기와 이어 붙일 수 없다 |
| `inProgressSession` | 진행 **중**인 세션이라 완주와 무관하다 |

## 2. 지금 쓰고 있는 우회 — 인물 목록을 찔러 본다

상세 화면이 열릴 때 `GET /api/children/{childId}/stories/{storyId}/free-talk/characters`
를 한 번 부르고, **인물이 돌아온 이야기 = 완주한 이야기**로 본다. 404·403·501·
네트워크 실패는 전부 삼키고 버튼만 안 그린다.
→ `StoryDetailViewModel._probeFreeTalk`

동작에는 문제가 없지만 대가가 있다.

- 이야기 상세를 열 때마다 **요청이 한 번 더 나간다.** 대부분은 404 로 버려진다.
- 404 를 "정상 흐름"으로 쓰고 있어서 서버 로그에 의미 없는 404 가 쌓인다.
- "완주했는지"라는 질문에 **자유 대화 API 로** 답하고 있다. 자유 대화 정책이
  바뀌면(예: 완주해도 특정 이야기는 대화 없음) 판정이 조용히 틀린다.

## 3. 요청 1 — `StoryDetailResponse.completed`

```jsonc
// GET /api/stories/{storyId}  (childId 는 인증 컨텍스트에서)
{
  "story": { ... },
  "sceneCount": 9,
  "childRole": "...",
  "intro": "...",
  "completed": true        // ← 이 아이가 이 이야기를 완주한 적이 있는지
}
```

`boolean` 이면 충분하다. `lastCompletedAt: OffsetDateTime?` 이면 나중에 목록에
"3일 전에 끝냈어" 같은 말을 붙일 수 있어 조금 더 낫지만, **둘 중 하나면 된다.**

받는 즉시 프런트는 2절의 프로브를 지우고 이 값으로 버튼을 그린다.

## 4. 요청 2 — `ReportListResponse.storyId`

이야기 **목록**(`/stories`)의 카드에도 "다 들었어" 도장을 찍는다. 여덟 편이
다 비슷해 보이는 목록에서 아이가 "어디까지 했지"를 알 길이 그것 말고 없다.

그런데 목록은 이야기 **한 편씩** 물어보는 자유 대화 프로브를 쓸 수 없다
(여덟 편이면 요청이 여덟 번). 완주 사실이 남는 곳은 리포트 목록뿐인데,
거기에 `storyId` 가 없어서 **제목 문자열로 맞추고 있다.**

```dart
// GetCompletedStoryTitlesUseCase — 임시
final ReportList list = await _reports.getReportList();
return <String>{ for (final r in list.reports) r.storyTitle.trim() };
```

같은 제목의 이야기가 둘 생기면 둘 다 완주로 보인다. 제목이 한 글자라도
바뀌면 도장이 사라진다. `storyId` 한 개면 둘 다 없어진다.

```jsonc
// GET /api/children/{childId}/reports
[{ "sessionId": "...", "storyId": "1111...",  // ← 이것
   "storyTitle": "방귀 뀌는 며느리", "completedAt": "...", "playCount": 1 }]
```

## 5. 프런트가 이미 해 둔 것

| 항목 | 위치 |
|---|---|
| 상세의 친구들 카드(얼굴 셋) | `free_talk_friends_card.dart` |
| 완주 도장(목록 카드 · 상세 표지 공용) | `completed_badge.dart` |
| 상세의 완주 판정(우회 ①) | `story_detail_view_model.dart` `_probeFreeTalk` · `isCompleted` |
| 목록의 완주 판정(우회 ②) | `get_completed_story_titles_use_case.dart` — 리포트 제목 매칭 |
| 미완주로 들어왔을 때의 안내 | `free_talk_characters_view.dart` — 에러가 아니라 "끝까지 들으면 친구들이 기다릴 거야" |
| 라우트 | `AppRoutes.freeTalkChatOf(storyId, characterId)` — 세션과 무관 |

자유 대화 엔드포인트 네 개가 아직 `⛔`(501) 라, **서버가 열리기 전에는 버튼이
저절로 안 뜬다.** 서버가 열리면 프런트 배포 없이 버튼이 생긴다.
