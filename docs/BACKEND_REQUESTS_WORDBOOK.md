# 백엔드 요청 — 단어장에 이야기 정보 (2026-08-16)

대상 저장소: `team-mugunghwa/goodquestion-backend` (`develop`)
대상 API: `GET /api/children/{childId}/words`

요청 배경: 단어장 화면(`/words`)을 실서버에 붙이면서 `WordResponse` 를 대조했다. 화면은 단어를
**이야기별로 묶어** 보여주는데, 응답에서 이야기를 알아낼 수 있는 값이 `sourceSceneId` 뿐이다.
장면 조회는 `GET /api/stories/{storyId}/scenes` 하나뿐이라 **`storyId` 를 이미 알아야** 장면을
볼 수 있다 — 장면에서 이야기로 되짚는 경로가 없어 프런트에서는 해결할 수 없다.

| # | 구분 | 내용 | 우선순위 |
|---|---|---|---|
| 1 | 계약 | `WordResponse` 에 `storyId` · `storyTitle` · `storyImageUrl` 추가 | 높음 |
| 2 | 성능 | 목록 조회에 `@EntityGraph` — 단어 수만큼 쿼리가 늘지 않도록 | 높음 |

**필드 추가·조회 힌트 두 가지가 전부다.** 아래에 적용 가능한 코드를 그대로 붙였다.

---

## 1. `WordResponse` 에 이야기 3필드

### 현재

```
id · word · meaning · exampleSentence · entryType · sourceSceneId · createdAt
```

### 요청

```
id · word · meaning · exampleSentence · entryType · sourceSceneId
   · storyId · storyTitle · storyImageUrl · createdAt
```

**관계는 이미 다 연결돼 있다.** `Wordbook.sourceScene` → `StoryScene.story` → `Story.title` /
`Story.imageUrl`. 새로 만들 것 없이 값을 꺼내 담기만 하면 된다.

이름은 이야기를 참조하는 기존 DTO 관례를 그대로 따랐다 —
`ShopItemResponse.UnlockGuide(storyTitle, storyImageUrl)` 와 `ReportListResponse.storyTitle`.

`sourceScene` 이 `null` 이면(장면 없이 저장된 단어) **세 값 모두 `null`** 이다. 프런트는 이 경우를
"이야기 없음" 묶음으로 그린다.

### `WordResponse.java`

```java
package com.mugunghwa.goodquestion.learning.wordbook.dto;

import com.mugunghwa.goodquestion.learning.wordbook.WordEntryType;
import com.mugunghwa.goodquestion.learning.wordbook.Wordbook;
import com.mugunghwa.goodquestion.story.content.Story;
import com.mugunghwa.goodquestion.story.content.StoryScene;

import java.time.OffsetDateTime;
import java.util.UUID;

/** 명세 3-15 단어. */
public record WordResponse(UUID id, String word, String meaning, String exampleSentence,
                           WordEntryType entryType, UUID sourceSceneId,
                           UUID storyId, String storyTitle, String storyImageUrl,
                           OffsetDateTime createdAt) {

    public static WordResponse from(Wordbook w) {
        StoryScene scene = w.getSourceScene();
        Story story = (scene != null) ? scene.getStory() : null;
        return new WordResponse(w.getId(), w.getWord(), w.getMeaning(), w.getExampleSentence(),
                w.getEntryType(),
                (scene != null) ? scene.getId() : null,
                (story != null) ? story.getId() : null,
                (story != null) ? story.getTitle() : null,
                (story != null) ? story.getImageUrl() : null,
                w.getCreatedAt());
    }
}
```

---

## 2. 목록 조회에 `@EntityGraph`

`sourceScene` 과 그 안의 `story` 가 둘 다 `LAZY` 라, 1번만 적용하면 목록을 부를 때 **단어 하나당
쿼리가 두 번씩 더** 나간다. 단어가 쌓일수록 느려지므로 조회 힌트를 같이 넣어 달라.

`create` · `toggleFavorite` 은 단어 하나만 다루므로 손대지 않아도 된다.

### `WordbookRepository.java`

```java
package com.mugunghwa.goodquestion.learning.wordbook;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface WordbookRepository extends JpaRepository<Wordbook, UUID> {

    boolean existsByChildIdAndWord(UUID childId, String word);

    /** 단어 소유 검증 — 아이가 둘인 보호자가 다른 아이의 단어를 건드리지 못하게 한다. */
    Optional<Wordbook> findByIdAndChildId(UUID id, UUID childId);

    @EntityGraph(attributePaths = {"sourceScene", "sourceScene.story"})
    List<Wordbook> findAllByChildIdOrderByCreatedAtDesc(UUID childId);

    @EntityGraph(attributePaths = {"sourceScene", "sourceScene.story"})
    List<Wordbook> findAllByChildIdAndEntryTypeOrderByCreatedAtDesc(UUID childId, WordEntryType entryType);
}
```

---

## 영향 범위

- **기존 필드는 이름·순서·타입 모두 그대로**다. 추가만 있어 기존 소비자는 깨지지 않는다.
- `WordbookServiceTest` 는 `WordResponse` 를 직접 생성하지 않고 접근자만 쓴다 → **컴파일 영향 없음.**
- `WordbookService` · `WordbookController` 는 수정할 것이 없다.

---

## 요청하지 **않는** 것

이 두 가지는 프런트에서 처리하기로 했으니 작업하지 말아 달라.

### 이야기별 그룹핑 응답

평면 목록 + `createdAt` 내림차순을 **지금 그대로 유지**해 달라. 이야기별 묶음은 위 3필드만
있으면 프런트에서 만들 수 있다. 응답 구조를 바꾸면 `POST` · `PATCH` 응답까지 같이 흔들린다.

### 단어 음성

`MVP_요건.md` 의 "음성 듣기 제공"은 당분간 **기기 내장 음성**으로 처리한다. 단어용 TTS나
음성 파일 필드는 필요 없다.

> 서버 TTS가 정식으로 도입되면 그때 다시 논의한다. 그전까지 이 항목으로 백엔드 일정을
> 잡지 않아도 된다.

---

## 참고 — 프런트가 자체 정정한 것

이 요청을 준비하며 기존 프런트 명세([API.md](API.md) 2.12)가 **기획 원본에 없는 필드를 요구하고
있었다**는 것을 확인했다. `totalCount` · `child.name` · `child.avatar` · `savedAt` · 그룹 구조는
화면을 만들며 프런트가 지어낸 것이고, 근거로 달아 둔 "PRD F-10"은 **양쪽 저장소 어디에도 없는
문서**다. 기획 원본은 백엔드 저장소의 `docs/기획/MVP_요건.md` 이며, 단어장 요구는 네 줄이다 —
모르는 단어 저장 · 쉬운 뜻과 이야기 속 문장 · 음성 듣기 · 좋아하는 단어 저장.

**백엔드 구현은 이 요건을 정확히 따르고 있었다.** 어긋난 쪽은 프런트이고, `API.md` 2.12 는
실제 계약에 맞춰 정리한다. 위 3필드만이 화면에 실제로 필요한 추가분이다.
