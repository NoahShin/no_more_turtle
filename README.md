# no_more_turtle

맥북 웹캠으로 자세를 모니터링하다가 거북목이 감지되면 화면에 거북이가 튀어나오는 macOS 메뉴바 앱.

## Tech Stack

- **Swift** + **SwiftUI** / **AppKit** (메뉴바 앱)
- **Vision** framework — `VNDetectHumanBodyPoseRequest`로 자세 감지
- **AVFoundation** — 웹캠 캡처
- **SpriteKit** — 거북이 애니메이션 오버레이

## Build

`.xcodeproj`는 [xcodegen](https://github.com/yonaskolb/XcodeGen)으로 `project.yml`에서 생성합니다 (git에는 커밋하지 않음).

```sh
brew install xcodegen
xcodegen generate
open NoMoreTurtle.xcodeproj
```

또는 CLI에서:

```sh
xcodebuild -project NoMoreTurtle.xcodeproj -scheme NoMoreTurtle -configuration Debug build
```

## Status

🐢 스캐폴딩 완료 — 메뉴바 앱, 카메라/Vision/Overlay 골격까지 빌드됨. 자세 감지 임계값 튜닝 + SpriteKit 애니메이션 작업 예정.
