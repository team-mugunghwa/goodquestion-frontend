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

> 홈의 이어하기·추천 카드는 **같은 이미지를 16:9로 가운데만 잘라** 씁니다(별도 파일 불필요).
> 그래서 **주인공을 세로 가운데에** 두는 게 중요합니다(아래 크롭세이프 규칙).

---

## 2. STYLE BASE (모든 표지에 그대로 복붙 — SUBJECT만 교체)

> 일관성은 **색이 아니라 그림체(스타일·기법)** 로 잡습니다. 색은 이야기마다 자유롭게.
> 여기 고정하는 건 ① 스토리북 그림체 ② 앱에 넣기 위한 기술 제약(세로 2:3·주인공 가운데·글자 없음)뿐입니다.

```
A rich, warm children's picture-book cover illustration for ages 7-9, based on a
classic Korean folk tale. Hand-drawn storybook style: soft painterly texture,
gentle rounded shapes, expressive friendly characters in hanbok with round faces
and big kind eyes, cozy inviting atmosphere, a touch of gentle magic. Full, vivid,
NATURAL colors — each cover uses whatever palette best fits its own story and mood
(warm sunsets, lush fields, cozy interiors, moonlit nights are all welcome).
Storybook lighting, soft depth, wholesome and friendly, never scary.
COMPOSITION: portrait 2:3, vertical book-cover framing. Keep the main character in
the VERTICAL CENTER so the middle also crops cleanly to a wide banner. Clean,
uncluttered, generous margins.
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
- [ ] 세로 2:3, 주인공은 **세로 가운데**, 글자 없음.
- [ ] 저장: `assets/images/covers/story_<id>.png` (표 그대로).

---

## 6. 자주 묻는 것

- **파일을 저장했는데 안 떠요** → 파일명·확장자·폴더가 표와 정확히 같은지 확인. 앱 완전 재시작(핫리스타트). 워크트리에서 실행 중이면 워크트리 쪽 `assets/images/covers/`에 저장했는지 확인.
- **아직 안 만든 표지는?** → 코드로 그린 임시 표지가 자동으로 대신 뜹니다. 하나씩 채워도 됩니다.
- **PNG가 무거워요** → 일단 PNG로 저장하세요. 나중에 WebP 일괄 변환은 개발 쪽에서 처리할 수 있습니다(파일명은 유지).
- **홈이랑 목록에 표지가 다르게 잘려 보여요** → 정상입니다. 목록은 세로 2:3 전체, 홈은 같은 이미지의 가운데 16:9. 그래서 주인공을 세로 가운데 두는 게 중요합니다.
