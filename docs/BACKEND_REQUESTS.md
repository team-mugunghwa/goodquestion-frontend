# 백엔드에 요청할 것

프론트 작업 중 발견한, 백엔드 계약을 바꿔야 풀리는 항목들. 발견한 순서대로
쌓습니다. 처리되면 표시하고 지우지 말고 남겨 두세요 — 왜 지금 이런 모양인지
나중에 다시 찾아보게 됩니다.

---

## 1. 단어장 응답에 이야기 정보가 없음

**상태**: 미해결 (2026-08-13 발견)

**어디**: `GET /api/children/{childId}/words` → `WordResponse`

### 무엇이 문제인가

`WordResponse` 는 `sourceSceneId`(장면 UUID) 만 내려주고, 그 장면이 어느
이야기인지(`storyId`·`storyTitle`·`storyImage`)는 안 줍니다.

```java
public record WordResponse(UUID id, String word, String meaning, String exampleSentence,
                           WordEntryType entryType, UUID sourceSceneId, OffsetDateTime createdAt)
```

프론트의 단어장 화면은 **이야기별로 묶어서** 보여주는 게 의도입니다
(`lib/features/word/domain/entities/word_group.dart` 주석 참고 — PRD F-10).
아이의 기억 단서가 "언제 담았나"가 아니라 "어떤 이야기에서 만났나"이기
때문입니다. 지금은 이걸 응답만으로 할 수 없어서, `WordRepositoryImpl` 이
전부 "최근 담은 단어" 그룹 하나에 몰아넣는 임시 처리를 하고 있습니다
(`lib/features/word/data/repositories/word_repository_impl.dart`).

`sourceSceneId` 로 장면→이야기를 되짚는 조회 엔드포인트도 따로 없어서,
단어마다 추가 조회를 하면 단어 개수만큼 요청이 늘어납니다(N+1). 지금
단어장 화면에서는 이 방법을 쓰지 않기로 했습니다.

### 원하는 것

`WordResponse` 에 아래 필드를 추가해 주세요. `Wordbook.sourceScene.getStory()` 로
이미 접근 가능한 값이라 조인 하나만 추가하면 될 것 같습니다.

```java
public record WordResponse(UUID id, String word, String meaning, String exampleSentence,
                           WordEntryType entryType, UUID sourceSceneId, OffsetDateTime createdAt,
                           UUID storyId, String storyTitle, String storyImageUrl)
```

`sourceScene` 이 `null` 인 단어(장면 없이 저장된 경우)는 `storyId` 등도
`null` 이면 됩니다 — 프론트가 그런 단어는 별도 그룹("이야기 밖에서 담은
단어" 같은)으로 묶겠습니다.

### 이게 풀리면 프론트가 할 일

- `lib/features/word/data/dtos/word_response_dto.dart` 에 세 필드 파싱 추가
- `lib/features/word/data/repositories/word_repository_impl.dart` 의
  "그룹 하나로 몰아넣기"를 실제 `storyId` 기준 그룹핑으로 교체
- 화면(`word_list_view.dart`)·뷰모델은 이미 그룹 여러 개를 다루도록
  만들어져 있어서 손댈 게 없습니다 (필터 칩도 그룹이 1개일 때만 숨기게
  해 뒀어서, 그룹이 여러 개가 되면 자동으로 다시 보입니다)
