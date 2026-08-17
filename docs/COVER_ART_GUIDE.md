# 이야기 표지 일러스트 — 제작·저장 가이드

이 문서 하나로 표지 이미지를 **일관되게 생성**하고, **앱에 자동으로 뜨는 위치·이름**에 저장하면 됩니다.
당신이 할 일은 딱 두 가지: **① 프롬프트로 이미지 생성 → ② 지정된 폴더에 지정된 이름으로 저장.**
코드는 손댈 필요 없습니다.

- 생성 도구: **ChatGPT(GPT-image)** 또는 **Gemini(Nano Banana / 2.5 Flash Image)**
- 배선 상태: `image` 경로는 이미 코드에 연결돼 있음. **파일을 저장하면 자동 표시**, 파일이 없으면 코드로 그린 임시 표지가 대신 뜸(앱 안 깨짐).

---

## 0. TL;DR — 당신이 할 일

1. 아래 **STYLE BASE**(고정)를 복사한다.
2. 표지별 **SUBJECT 한 줄**을 뒤에 붙여 생성한다. (세로 2:3, 글자 없이)
3. 결과를 아래 **파일명 표**대로 `assets/images/covers/` 에 **PNG**로 저장한다.
4. 끝. 앱을 다시 실행하면 표지가 뜬다.

> 홈 히어로에 쓰는 **가로 전용 표지(2.5:1, WebP)** 는 별도입니다 →
> [8장](#8-가로-전용-표지-홈-히어로--확정-규격). 7편 중 **2편만 만들기로 했고**, 나머지는
> 위 세로 표지로 폴백합니다 — 미완이 아니라 정해진 모양입니다.

---

## 1. 저장 규격 (반드시 이대로)

| 항목 | 값 |
|---|---|
| 저장 폴더 (repo 기준) | `assets/images/covers/` |
| 저장 폴더 (절대경로) | `C:\dev\goodquestion-frontend\assets\images\covers\` |
| 파일 형식 | **PNG** (`.png`) — 확장자까지 정확히 |
| 비율 | **세로 2:3** (그림책 표지) |
| 권장 크기 | **1024 × 1536** 이상 (같은 2:3면 더 커도 OK, 예: 1365×2048) |
| 글자 | **넣지 않음** (제목·칩은 앱이 얹음) |
| 색 | **이야기에 맞게 자유** (일관성은 색이 아니라 그림체로) |

> ⚠️ 파일명이 **한 글자라도 다르면** 표지가 안 뜨고 임시 표지가 나옵니다. 아래 표 그대로 저장하세요.
> ⚠️ 워크트리에서 작업 중이면 실제 저장 경로는
> `C:\dev\goodquestion-frontend\.claude\worktrees\feat+home-visual-polish\assets\images\covers\` 입니다.
> (헷갈리면 최종적으로는 위 메인 경로 `assets\images\covers\` 기준으로 생각하면 됩니다.)

### 파일명 표 (이야기 ↔ 파일명)

| storyId | 이야기 | 주제 | **저장 파일명** |
|---|---|---|---|
| 11 | 방귀 뀌는 며느리 | 가족 | `story_11.png` |
| 21 | 해와 달이 된 오누이 | 용기 | `story_21.png` |
| 22 | 의좋은 형제 | 우정 | `story_22.png` |
| 23 | 흥부와 놀부 | 가족 | `story_23.png` |
| 31 | 토끼와 거북이 | 용기 | `story_31.png` |
| 32 | 호랑이와 곶감 | 용기 | `story_32.png` |
| 41 | 학교 가는 길 | 일상 | `story_41.png` |

> **표지는 자르지 않습니다.** 홈 책장("새로운 이야기") · 이야기 목록 · 이야기 상세 ·
> 홈 히어로가 전부 이 세로 2:3 그림을 **그대로** 씁니다. 그러니 이 한 장만 잘 그리면 됩니다.
> (2026-08-17 확정. [7장](#7-표지는-자르지-않는다) 참고)
>
> 홈 히어로는 가로로 긴 자리라 **가로 전용 표지(2.5:1)** 를 따로 씁니다 — 그건 세로 표지와
> 별개의 그림이고 규격은 [8장](#8-가로-전용-표지-홈-히어로--확정-규격)에 있습니다. 아직 두
> 편뿐이고, 없는 편은 이 세로 표지를 세워서 보여 줍니다.

---

## 2. STYLE BASE (모든 표지에 그대로 복붙 — SUBJECT만 교체)

> 일관성은 **색이 아니라 그림체(스타일·기법)** 로 잡습니다. 색은 이야기마다 자유롭게.
> 여기 고정하는 건 ① 스토리북 그림체 ② 앱에 넣기 위한 기술 제약(세로 2:3·글자 없음)뿐입니다.

> **2026-08-17 에 COMPOSITION 한 문장을 고쳤습니다.** 원래는
> `Keep the main character in the VERTICAL CENTER so the middle also crops cleanly to a wide banner`
> 였습니다 — 홈이 이 그림을 16:9로 잘라 쓰던 시절의 제약입니다. 이제 **어느 화면도 세로
> 표지를 자르지 않으므로**(가로가 필요한 홈 히어로는 [8장](#8-가로-전용-표지-홈-히어로--확정-규격)의
> 별도 그림을 씁니다) 그 제약을 지우고 **"인물을 화면 안에 여유 있게"** 만 남겼습니다.
> 이미 뽑아 둔 일곱 장은 다시 뽑지 않아도 됩니다. 세로 표지는 이제 **위아래 어디를 잡든**
> 자유입니다.

```
A rich, warm children's picture-book cover illustration for ages 7-9, based on a
classic Korean folk tale. Hand-drawn storybook style: soft painterly texture,
gentle rounded shapes, expressive friendly characters in hanbok with round faces
and big kind eyes, cozy inviting atmosphere, a touch of gentle magic. Full, vivid,
NATURAL colors — each cover uses whatever palette best fits its own story and mood
(warm sunsets, lush fields, cozy interiors, moonlit nights are all welcome).
Storybook lighting, soft depth, wholesome and friendly, never scary.
COMPOSITION: portrait 2:3, vertical book-cover framing. Keep the main character
fully inside the frame, comfortably away from the edges. Clean, uncluttered,
generous margins.
NO text, no letters, no title, no watermark, no logo, no UI, no border.
```

### 표지별 SUBJECT (위 BASE 뒤에 한 줄만 이어 붙이기)

| 파일명 | SUBJECT (append) |
|---|---|
| `story_11.png` | `A young woman in green hanbok laughing gently by a traditional giwa-roofed house, a soft playful gust of pastel wind swirling leaves, warm family smiling nearby.` |
| `story_21.png` | `A brave little brother and sister in hanbok climbing a soft glowing rope up into a pale sky, a gentle mint sun and blue moon shaped like puffy bubbles above.` |
| `story_22.png` | `Two brothers in hanbok walking toward each other across a soft green rice field at dawn, each carrying a rice sack, warm friendly expressions.` |
| `story_23.png` | `A kind family in hanbok in front of a cozy giwa-roofed house, a friendly pastel swallow carrying a tiny magic gourd seed, gentle green hills.` |
| `story_31.png` | `A cheerful round rabbit and a calm smiling turtle side by side on a soft green hill path, gentle friendly race, pastel clouds.` |
| `story_32.png` | `A big soft FRIENDLY (not scary) pastel tiger with round gentle eyes peeking curiously at a small basket, cozy village in cool soft blue, playful and calm.` |
| `story_41.png` | `A happy child with a round backpack walking a gentle path to a soft pastel school building, morning light, small friendly animals along the way.` |

---

## 3. ChatGPT(GPT-image)로 뽑을 때

- 프롬프트에 비율을 강하게 명시: `"portrait 2:3, vertical, tall book-cover framing"`.
- **네거티브 프롬프트가 없어도** BASE에 `"NO text… no border"`가 들어 있어 그대로면 됨(글자·워터마크 방지). 색은 일부러 안 막음.
- **일관성**: ① 앵커 1장을 먼저 뽑아 스타일을 확정 → ② **같은 대화창에서** "같은 아트 스타일·색·질감으로, 이번엔 [SUBJECT]"로 이어가기 → ③ 더 확실히 하려면 앵커 이미지를 **업로드해 참조**시키기("keep this exact style").

## 4. Gemini(Nano Banana / 2.5 Flash Image)로 뽑을 때 — 세트 만들기엔 이쪽이 강함

- **앵커 이미지를 넣고** `"in the exact same art style, palette, and rendering as this reference image, create a portrait 2:3 cover for: [SUBJECT]"`.
- Gemini는 참조 스타일·캐릭터 유지가 잘 돼서 **7장을 한 결로** 맞추기 좋음. 같은 세션에서 SUBJECT만 교체.
- 비율: `"aspect ratio 2:3, vertical"`.

## 5. 일관성 체크리스트

- [ ] STYLE BASE는 **한 글자도 안 바꾼다**. SUBJECT 문장만 교체.
- [ ] **앵커 1장 먼저** → 그 스타일을 참조/시드로 나머지에 전파.
- [ ] 색은 이야기에 맞게 자유. **일관성은 그림체(스타일)로** 잡고 색으로 맞추지 않는다.
- [ ] 세로 2:3, 인물은 **화면 안에 여유 있게**, 글자 없음.
- [ ] 저장: `assets/images/covers/story_<id>.png` (표 그대로).

---

## 6. 자주 묻는 것

- **파일을 저장했는데 안 떠요** → 파일명·확장자·폴더가 표와 정확히 같은지 확인. 앱 완전 재시작(핫리스타트). 워크트리에서 실행 중이면 워크트리 쪽 `assets/images/covers/`에 저장했는지 확인.
- **아직 안 만든 표지는?** → 코드로 그린 임시 표지가 자동으로 대신 뜹니다. 하나씩 채워도 됩니다.
- **PNG가 무거워요** → 일단 PNG로 저장하세요. 나중에 WebP 일괄 변환은 개발 쪽에서 처리할 수 있습니다(파일명은 유지).
- **홈 맨 위 히어로에 세로 표지가 통째로 서 있어요** → 정상입니다. 그 편의 **가로 전용 표지가 아직 없다**는 뜻입니다(8장). 가로 표지를 넣으면 그 편부터 가로 패널로 바뀝니다.
- **표지가 잘려 보여요** → **버그입니다. 알려 주세요.** 어느 화면에서도 자르지 않습니다(2026-08-17 부터 홈 히어로 포함). 화면마다 표지 **크기**는 다를 수 있어도(홈 책장이 가장 작습니다) 잘린 데는 없어야 합니다.
- **표지가 화면마다 크기가 달라요** → 정상입니다. 비율(2:3)만 같고 크기는 그 자리의 세로 예산이 정합니다. 홈 책장은 첫 화면 안에 표지와 제목이 다 들어오도록 남은 세로에서 거꾸로 계산합니다.

---

## 7. 표지는 자르지 않는다

**확정 원칙 (2026-08-17)**

> **표지는 자르지 않는다. 자를 수밖에 없는 자리라면, 그 자리 비율로 그려진 그림을 따로 쓴다.**

### 왜

그림책 표지는 인물 전신 + 여백으로 구성된 **세로 그림**입니다. 이걸 가로 비율에 억지로 담으면
`BoxFit.cover` 가 위아래를 잘라내는데, 남는 건 표지가 아니라 장면 클로즈업입니다.
16:9 카드에 담으면 원본 세로의 **44%** 만 남고, 홈 히어로 같은 전폭 배너에서는 그보다 훨씬
적게 남습니다(아래 실측).

저학년 아동은 **색·이미지·시각 디자인으로 책을 고릅니다.** 표지가 곧 그 책의 정체성이라,
얼굴이 가려지면 고르는 근거 자체가 사라집니다.

한 벌의 이미지로 여러 비율을 감당하려는 시도는 업계가 이미 접었습니다. Apple TV 는 파트너에게
2:3 · 16:9 · 1:1 을 **각각 별도 에셋**으로 요구합니다
([Artwork Requirements](https://itunespartner.apple.com/tv-movies/support/5450-artwork-requirements)).
반대로 **책 앱들은 세로 표지를 통째로 보여주고 자르지 않습니다.**
우리는 이야기 앱이므로 후자를 따릅니다.

### 그래서 화면은 어떻게 되나

| 화면 | 표지가 놓이는 방식 | 자르나 |
|---|---|---|
| **홈 히어로**(이어하기·오늘의 이야기·폴백) | **가로 전용 표지 2.5:1** 을 카드 왼쪽 패널에. 없으면 세로 2:3 을 세움 | 안 자름 |
| 홈 책장("새로운 이야기") | 세로 2:3 표지를 나란히. 제목은 표지 밑 작은 라벨 | 안 자름 |
| 이야기 목록 `/stories` | 세로 2:3 표지 + 제목 + 칩 (카드) | 안 자름 |
| 이야기 상세 | 태블릿은 세로 2:3 그대로 | 안 자름 |

**2026-08-17 기준 예외는 없습니다.** 한동안 홈 히어로 하나가 예외였습니다 — 가로로 긴 배너에
세로 2:3 을 담느라 태블릿에서 원본 세로의 9% 만 남기고, 흰 글자를 읽히려고 검은 스크림까지
덮었습니다. 그 자리 비율로 그린 **가로 전용 표지**가 들어오면서 원칙의 후단("자를 수밖에 없는
자리라면 그 비율로 그려진 그림을 따로 쓴다")이 실행됐고, 크롭도 스크림도 사라졌습니다.

---

## 8. 가로 전용 표지 (홈 히어로) — 확정 규격

### 저장 규격

| 항목 | 값 |
|---|---|
| 저장 폴더 | `assets/images/covers/wide/` |
| 파일 이름 | `story_<id>.webp` — 세로 표지와 **같은 id** |
| 파일 형식 | **WebP** (`.webp`) |
| 비율 | **2.5 : 1** (가로로 긴 그림) |
| 권장 크기 | **2000 × 800** (지금 들어온 원본은 1983×793) |
| 글자 | **넣지 않음** |

> **WebP 로 넣습니다.** 세로 표지와 다른 점입니다. 히어로는 첫 화면에서 가장 먼저·가장 크게
> 뜨는 그림이라 로딩이 곧 첫인상입니다. PNG 원본은 장당 약 **2.5MB**, WebP 로 변환하면 약
> **240KB** — 10분의 1 입니다. 그리는 쪽은 PNG 로 뽑아도 되고, **저장소에는 WebP 만** 넣습니다
> (변환 전 PNG 는 커밋하지 않습니다). `assets/images/dialogue/` 도 같은 규칙입니다.

### 들어온 것 (2편)

| storyId | 이야기 | 가로 표지 |
|---|---|---|
| 11 | 방귀 뀌는 며느리 | ✅ `wide/story_11.webp` |
| 22 | 의좋은 형제 | ✅ `wide/story_22.webp` |
| 21 | 해와 달이 된 오누이 | — 세로 폴백 |
| 23 | 흥부와 놀부 | — 세로 폴백 |
| 31 | 토끼와 거북이 | — 세로 폴백 |
| 32 | 호랑이와 곶감 | — 세로 폴백 |
| 41 | 학교 가는 길 | — 세로 폴백 |

**나머지 다섯 편은 만들 계획이 없습니다** (2026-08-17 결정). 그러니 세로 폴백은 "아직
안 채운 자리"가 아니라 **평소 모양**입니다 — 히어로가 세로 2:3 표지를 왼쪽에 세우고,
그쪽도 자르지 않습니다. 두 모양이 한 화면에 섞여 보여도 정상입니다.

나중에 마음이 바뀌어 한 편을 그려 넣으면, 그 편만 가로 패널로 바뀝니다. 코드는
손댈 필요 없이 아래 표에 한 줄만 추가하면 됩니다.

### 그릴 때 (SUBJECT 는 세로 표지와 같은 장면으로)

2장의 STYLE BASE 를 쓰되 COMPOSITION 한 줄만 바꿉니다.

```
COMPOSITION: wide 2.5:1 horizontal banner framing. Spread the characters and the
scene ACROSS the full width, comfortably away from the edges. Clean, uncluttered.
```

- **인물이 가로로 퍼져도 됩니다.** 자르지 않으니까요 — 세로 표지처럼 "가운데에 모아야 한다"는
  제약이 없습니다. `story_11` 은 다섯 명이 좌우로 늘어서 있고 그대로 다 보입니다.
- 세로 표지와 **같은 그림체·같은 인물**이어야 합니다. 같은 이야기가 홈에서는 가로, 목록에서는
  세로로 보이는데 인상이 달라지면 아이는 다른 책으로 셉니다. 세로 표지를 참조 이미지로 넣고
  `"same characters, same art style, now as a wide 2.5:1 banner"` 로 뽑으세요.

### 코드가 찾는 방법

`StoryThumbnail.localWideCoverAssetFor(제목)` 하나입니다. **제목 → 파일** 표에 있는 편만 가로
표지가 있다고 보고, 없으면 `null` 을 돌려줘서 홈이 세로 폴백을 고릅니다. 파일을 넣을 때
그 표(`_localWideCoverByTitle`)에 한 줄 추가하세요.

에셋이 실제로 있는지 **런타임에 확인하지 않습니다** — 웹에서는 없는 파일을 부르는 순간 404 가
콘솔에 남습니다. 표가 유일한 진실입니다.

`pubspec.yaml` 에도 `assets/images/covers/wide/` 가 **따로** 등록돼 있어야 합니다. Flutter 는
`assets/images/covers/` 를 등록해도 하위 폴더를 재귀 포함하지 않습니다.
