# 🐢 no_more_turtle

맥북 웹캠으로 자세를 모니터링하다가 거북목이 감지되면 화면 오른쪽에서 거북이가 슬라이드 인 하는 macOS 메뉴바 앱.

## 다운로드 & 설치

1. [GitHub Releases](https://github.com/NoahShin/no_more_turtle/releases)에서 최신 `.dmg` 다운로드
2. 더블클릭으로 마운트 → `NoMoreTurtle.app`을 `Applications` 폴더로 드래그
3. 앱 더블클릭하면 다음 화면이 뜹니다:
   > "Apple이 'NoMoreTurtle'에 멀웨어가 없는지 확인할 수 없습니다."
4. **Done** 클릭 → **System Settings → Privacy & Security** 열기
5. 맨 아래로 스크롤하면 "NoMoreTurtle was blocked to protect your Mac" 메시지 옆에 **Open Anyway** 버튼 → 클릭
6. 비밀번호/Touch ID 인증 후 한 번 더 **Open** 클릭 → 정상 실행

> ⚠️ macOS 15 Sequoia부터 우클릭 → "열기" 트릭은 막혔어요. 위의 System Settings 경로가 표준입니다.
>
> **터미널 한 줄 우회**: `xattr -dr com.apple.quarantine /Applications/NoMoreTurtle.app` 실행하면 위 3-6 단계 다 건너뛰고 더블클릭으로 그냥 열려요.

**한 번만 이렇게 설치하면 이후 모든 업데이트는 앱 내 Settings → "업데이트 확인" 버튼으로 자동**입니다 (System Settings 다시 안 가도 됨).

**요구사항:** macOS **26.0+**

## 🔒 Privacy (중요)

**이 앱은 카메라가 본 영상을 어디에도 저장하거나 전송하지 않습니다.**

- 비디오/사진/스크린샷 파일로 **저장하지 않음**
- 카메라 데이터를 네트워크/클라우드로 **전송하지 않음**
- 외부 분석 SDK, 텔레메트리, 광고 SDK **없음** — Apple 내장 프레임워크만 사용
- 카메라 프레임은 **메모리에서만** Apple의 [Vision](https://developer.apple.com/documentation/vision) framework가 처리하고 즉시 폐기됨

**디스크에 영구 저장되는 것은 아래가 전부:**

| 위치 | 내용 |
|---|---|
| `UserDefaults` (`~/Library/Preferences/io.github.noahshin.NoMoreTurtle.plist`) | 캘리브레이션 좌표 (정규화된 4D 숫자), 설정값 (민감도/크기/투명도/자동시작) |

**네트워크 호출:** 단 한 군데, **사용자가 Settings에서 "업데이트 확인" 버튼을 누를 때만** `api.github.com/repos/NoahShin/no_more_turtle/releases/latest`에 GET 요청을 보냅니다. 업데이트 흐름의 일부 (현재 버전 vs 최신 버전 비교)이고, 카메라 데이터는 일절 포함되지 않습니다. 자동 체크 없음 — 클릭해야만 발생.

의심되면 `~/no_more_turtle/NoMoreTurtle/` 안의 Swift 소스 직접 확인하시면 됩니다 — 전체 코드 1000줄 안쪽이라 한 번에 다 읽힙니다.

## 동작 방식

1. **Calibrate good posture** (⌘G) — 평소 좋은 자세 잡고 클릭. 얼굴 위치/크기 기록
2. **Calibrate turtle posture** (⌘T) — 일부러 거북목 자세 잡고 클릭. 또 기록
3. 두 기록의 **차이 벡터**가 "이 사용자의 거북목 방향". 매 프레임마다 현재 얼굴 위치가 이 벡터를 따라 얼마나 진행했는지 점수화 (`0` = 좋은 자세, `1` = 캘리브레이션한 거북목)
4. 점수가 threshold (기본 0.65)를 넘기고 ~0.27s 유지되면 거북이 등장
5. 점수가 다시 내려가서 ~0.5s 유지되면 거북이 퇴장

캘리브레이션이 카메라 각도/위치에 의존하지 않게 만들어서 — 노트북이 정면이든 옆에 비스듬히 있든 자기 자세만 일관되면 잘 작동합니다.

## 개발 빌드

```sh
brew install xcodegen
xcodegen generate
open NoMoreTurtle.xcodeproj   # Xcode에서 ▶️
```

CLI:
```sh
xcodebuild -project NoMoreTurtle.xcodeproj -scheme NoMoreTurtle -configuration Debug build
```

## 배포용 .dmg 만들기

```sh
./scripts/build-release.sh 0.1.0   # 버전 인자
# → build/NoMoreTurtle-0.1.0.dmg
```

스크립트는 Release 빌드 → ad-hoc 서명 → `Applications` 심볼릭 링크 포함한 DMG 생성. GitHub Releases 업로드는:

```sh
gh release create v0.1.0 build/NoMoreTurtle-0.1.0.dmg --title "v0.1.0"
```

요구사항:
- macOS **26.0+** (Liquid Glass 앱 아이콘 때문)
- Xcode **26+** (Icon Composer 동봉)
- xcodegen (`brew install xcodegen`)

## Tech Stack

- **AppKit** 메뉴바 앱 (`LSUIElement=true`, Dock 미등장)
- **AVFoundation** — 웹캠 캡처
- **Vision** — `VNDetectFaceRectanglesRequest` (얼굴 bbox, 각도 강건)
- **SwiftUI** — 환경설정 윈도우
- **Combine** — 설정 변경 실시간 반영
- **Icon Composer** — Liquid Glass 앱 아이콘 (`AppIcon.icon`)
- **xcodegen** — `.xcodeproj`를 `project.yml`에서 생성 (생성물은 git ignore)

## Status

🐢 동작 OK. 후속 작업 후보:
- GitHub Releases용 .dmg 배포
- 로그인 시 자동 실행
- 거북목 감지 통계 (오늘/이번주)
- 거북이 캐릭터 커스터마이즈
