# PohangAirAR

포항시청 중심 좌표의 현재 기온, PM2.5와 UV Index를 Open-Meteo에서 가져와 최초 사용자 위치를 중심으로 중력 정렬 월드 공간에 RealityKit 시각화를 배치하는 iOS 17 교육용 앱입니다.

> 이 앱의 AR 기능은 카메라와 6DoF 월드 트래킹이 필요한 기능입니다. 시뮬레이터가 아닌 ARKit 지원 iPhone 또는 iPad에서 최종 확인해야 합니다.

## 완성 화면과 사용자 흐름

앱을 열면 상단에 `온도 | 미세먼지 | UV`가 한 줄로 표시됩니다. 데이터와 공간 추적이 준비되면 황토색 먼지는 최초 사용자 위치의 360° 주변에 분포하고, UV 스펙트럼은 그 위치 위쪽의 한 월드 지점에서 아래로 퍼집니다. 기기를 회전해도 화면에 붙은 HUD처럼 따라오는 대신 실제 공간에 고정된 시각화를 다른 방향에서 계속 볼 수 있습니다. PM2.5가 심각 수준이면 입자 수와 분포 면적이 크게 늘어나며, UV Index가 높을수록 낮게 시작한 광선 불투명도가 올라갑니다. 하단 조작은 `새로고침` 하나만 제공합니다.

## 기술 스택

- Swift 5, SwiftUI, async/await, URLSession
- ARKit `ARWorldTrackingConfiguration`, RealityKit `ARView`, 투명 스프라이트와 프레임 애니메이션
- iOS 17.0 이상, Xcode 15 이상
- XCTest, DocC, GitHub Actions와 GitHub Pages

## 아키텍처

```text
Open-Meteo API
→ OpenMeteoAirQualityService
→ AirQualityViewModel
→ SwiftUI 오버레이
→ AirQualityEntityFactory
→ 중력 정렬 월드 앵커
```

API 응답 DTO와 앱의 `AirQualitySnapshot`을 분리했습니다. AR 시각화 개수와 정규화는 `AirQualityVisualizationMapper`에 순수 함수로 분리해 기기나 RealityKit 없이 테스트할 수 있습니다.

## 프로젝트 구조

```text
PohangAirAR/
├── App, Models, Services, ViewModels
├── AR, Views, Resources
└── Documentation.docc
PohangAirARTests/
Scripts/generate_assets.py
.github/workflows/deploy-docc.yml
```

## 실행 요구사항과 카메라 권한

1. `PohangAirAR.xcodeproj`를 Xcode에서 엽니다.
2. PohangAirAR Target의 Signing Team을 선택합니다.
3. iOS 17 이상을 실행하는 ARKit 지원 실제 기기를 연결합니다.
4. 앱을 실행하고 카메라 권한을 허용합니다.
5. 주변을 천천히 비추면 정상 추적 상태에서 시각화가 자동으로 배치됩니다.

카메라는 포항 환경 데이터를 주변 공간에 증강현실로 표시하는 데만 사용합니다. 앱은 고정된 포항 좌표를 사용하므로 위치 권한을 요청하지 않습니다.

## API

요청 주소는 `URLComponents`와 `URLQueryItem`으로 구성하며 API Key가 필요하지 않습니다.

```text
https://air-quality-api.open-meteo.com/v1/air-quality
latitude=36.0190
longitude=129.3434
current=pm2_5,uv_index
timezone=Asia/Seoul
```

## 빌드와 테스트

```bash
xcodebuild -project PohangAirAR.xcodeproj \
  -scheme PohangAirAR \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild -project PohangAirAR.xcodeproj \
  -scheme PohangAirAR \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO test
```

시뮬레이터 이름은 `xcrun simctl list devices available` 결과에 맞게 바꿉니다. 단위 테스트는 실제 네트워크를 호출하지 않습니다.

## 에셋 재생성

```bash
python3 Scripts/generate_assets.py
```

표준 라이브러리만 사용하는 스크립트가 텍스트 없는 1024px 앱 아이콘과 DocC용 SVG 개념도를 생성합니다. `DustParticle`과 `UVSpectrum`은 이 프로젝트를 위해 생성한 투명 PNG 디자인이며 앱과 DocC에서 함께 사용합니다.

## DocC 빌드

```bash
xcodebuild docbuild \
  -project PohangAirAR.xcodeproj \
  -scheme PohangAirAR \
  -destination 'generic/platform=iOS' \
  -derivedDataPath ./DerivedData \
  CODE_SIGNING_ALLOWED=NO
```

Xcode의 Product → Build Documentation으로도 튜토리얼을 열 수 있습니다.

## GitHub Pages

`main`에 Push하거나 Actions에서 `Deploy DocC to GitHub Pages`를 수동 실행하면 DocC 아카이브를 정적 호스팅 형식으로 변환해 배포합니다.

1. GitHub 저장소의 Settings → Pages로 이동합니다.
2. Source를 **GitHub Actions**로 설정합니다.
3. `main`에 워크플로를 포함한 변경을 Push합니다.

프로젝트 저장소 이름을 Hosting Base Path로 사용하므로 사용자/조직 사이트가 아닌 프로젝트 사이트에서도 상대 링크가 작동합니다.

## 알려진 제한사항

- 앱은 포항시청 중심 좌표(`36.0190`, `129.3434`)의 모델 데이터를 사용합니다.
- PM2.5와 UV 데이터는 현장 관측소의 실시간 직접 측정값이 아니라 Open-Meteo가 제공하는 데이터입니다.
- 입자 수와 UV 오브젝트 크기는 학습을 위한 표현이며 공식 건강 기준이 아닙니다.
- 건강 또는 의료 판단에 사용하면 안 됩니다.
- AR 기능은 시뮬레이터가 아닌 실제 ARKit 지원 기기에서 확인해야 합니다.
- 네트워크가 없거나 API 형식이 달라지면 한국어 오류 메시지가 표시되며 하단 새로고침으로 다시 요청할 수 있습니다.
