# 엄마, 밀어! (Mom, Push!)

타임루프 암살자 색출 병맛 물리 FPS — Godot 4.6 프로토타입.

### ▶ [브라우저에서 바로 플레이](https://kiliuswook.github.io/mom-push/)

설치 없이 돌아간다. 첫 로딩 약 10MB. 화면을 한 번 클릭하면 마우스 시점이 잡힌다.

병원에서 깨어난 휠체어 킬러가 마을에 숨은 암살자들을 찾아내고, 죽을 때마다 정체를
기억해가며, 모든 킬러를 제거한 뒤 탈출 지점까지 도달하는 게임.
아무나 쏘면 경찰 → SWAT → 헬기 → 전투기가 몰려와 반드시 망한다.

## 실행

```
godot --path . scenes/main.tscn
```

## 조작

| 키 | 동작 |
|---|---|
| WASD | 휠체어 굴리기 — **굴리는 동안에는 쏠 수 없다** |
| 마우스 / 우클릭 / 좌클릭 | 시점 / 조준 / 사격 |
| R | 재장전 (6발) |
| **Shift** | **엄마! 밀어!** — 고속 이동, 이 상태에서는 사격 가능 |
| Ctrl | 급정지 |
| Space | 휠체어 점프 (밀리는 중) |
| P | 엄마가 휠체어를 들어 계단 오르기 |
| Tab | 지금까지 파악한 킬러 |
| G | 루프 되감기 |
| Enter | 엄마를 2P 가 직접 조작 (IJKL·U·O·P / 게임패드) |

## 핵심 규칙

1. **직접 굴리는 동안에는 사격 불가.** 멈추거나, 관성으로 굴러가거나, 엄마가 밀 때만 쏠 수 있다.
2. **민간인을 죽이면 수배가 오른다.** 되돌릴 수 없다.
3. **킬러 배치는 판마다 고정.** 죽어서 얻은 정보는 다음 루프에서 그대로 쓸모가 있다.
4. **모든 킬러를 제거하기 전에 탈출 지점에 들어가면 포위당한다.**

## 검증

```
godot --headless --path . tests/smoke_check.tscn
```

62개 체크. 실제 물리를 돌려 이동 속도와 구동 상태 전이까지 확인한다.

## 웹 빌드 / 배포

```
python tools/subset_font.py                                        # 한글 폰트 서브셋 (10MB -> 0.25MB)
godot --headless --path . --export-release "Web" build/web/index.html
python tools/serve.py                                              # http://127.0.0.1:8060 에서 확인
```

`variant/thread_support=false` 로 빌드하므로 SharedArrayBuffer 가 필요 없고,
COOP/COEP 헤더 없는 정적 호스팅(GitHub Pages 등)에 그대로 올라간다.
배포는 `build/web` 의 내용을 `gh-pages` 브랜치 루트에 올리면 된다 (`.nojekyll` 포함).

자세한 내용은 `CLAUDE.md` 와 `docs/GDD.md`.

## 라이선스 주의

`assets/fonts/NotoSansKR.ttf` 는 SIL Open Font License 1.1.
