# AirAR

기기의 현재 위치에서 기온, UV Index와 지상 풍속·풍향은 Apple WeatherKit으로, PM2.5는 Open-Meteo Air Quality API로 조회하고 RealityKit 시각화를 배치하는 iOS 17 교육용 앱입니다.

> 이 앱의 AR 기능은 카메라와 6DoF 월드 트래킹이 필요한 기능입니다. 시뮬레이터가 아닌 ARKit 지원 iPhone 또는 iPad에서 최종 확인해야 합니다.

## 완성 화면과 사용자 흐름

앱을 열면 상단에 `온도 | 미세먼지 | UV`가 한 줄로 표시됩니다. 황토색 먼지는 Open-Meteo PM2.5 농도에 따라 최초 사용자 위치의 360° 주변에 분포하고 WeatherKit 풍향의 반대쪽으로 흐릅니다. UV 스펙트럼은 그 위치 위쪽의 한 월드 지점에서 아래로 퍼집니다.

## 기술 스택

- Swift 5, SwiftUI, async/await, WeatherKit, URLSession
- ARKit `ARWorldTrackingConfiguration`, RealityKit `ARView`, 투명 스프라이트와 프레임 애니메이션
- iOS 17.0 이상, Xcode 15 이상
- XCTest, DocC, GitHub Actions와 GitHub Pages

## 아키텍처

```text
Core Location → 현재 좌표/지역 이름
Apple WeatherKit (`WeatherService`) ─┐
Open-Meteo Air Quality API (PM2.5) ─┴→ CombinedEnvironmentService
→ AirQualityViewModel
→ SwiftUI 오버레이
→ AirQualityEntityFactory
→ 중력·북쪽 정렬 월드 앵커
```

WeatherKit 프레임워크 타입과 Open-Meteo 응답 DTO를 앱의 `AirQualitySnapshot`에서 분리했습니다. `CombinedEnvironmentService`가 두 요청을 병렬 실행해 하나의 스냅샷으로 합치고, ViewModel과 View는 데이터 출처별 구현을 알 필요가 없습니다.

상단 상태는 `매우 좋음 → 좋음 → 보통 → 나쁨 → 매우 나쁨` 순서로 표시합니다. PM2.5는 에어코리아 경계값 15/35/75㎍/㎥를 유지하면서 공식 `좋음` 구간을 8㎍/㎥에서 둘로 나누고, UV는 기상청 5단계 경계값 2/5/7/10을 사용합니다.

## 프로젝트 구조

```text
AirAR/
├── App/
├── Models/
├── Services/
├── ViewModels/
├── Views/
├── AR/
├── Resources/
├── Documentation.docc/
└── Info.plist
AirARTests/
├── Models/
├── Services/
├── ViewModels/
└── AR/
Scripts/generate_assets.py
.github/workflows/deploy-docc.yml
```

## 실행 요구사항과 권한

1. `AirAR.xcodeproj`를 Xcode에서 엽니다.
2. Apple Developer 계정의 App ID에서 WeatherKit을 활성화하고 AirAR Target의 Signing Team을 선택합니다.
3. Signing & Capabilities에서 WeatherKit entitlement가 적용됐는지 확인합니다.
4. iOS 17 이상을 실행하는 ARKit 지원 실제 기기를 연결합니다.
5. 앱을 실행하고 `앱을 사용하는 동안` 위치 권한과 카메라 권한을 허용합니다.
6. 주변을 천천히 비추면 정상 추적 상태에서 시각화가 자동으로 배치됩니다.

위치는 현재 지역의 환경 데이터를 조회하는 데만 사용하고, 카메라는 그 데이터를 주변 공간에 증강현실로 표시하는 데만 사용합니다. 첫 위치 요청에서는 iOS 표준 권한 창이 표시되며, 거부한 경우 앱의 `위치 설정 열기` 버튼으로 설정을 다시 열 수 있습니다. 백그라운드 위치를 사용하지 않으므로 `항상 허용` 권한은 요청하지 않습니다.

## 두 가지 데이터 요청 방식

### WeatherKit

WeatherKit 경로는 REST URL이나 `URLSession`을 직접 다루지 않습니다. 현재 좌표를 `CLLocation`으로 만들고 `WeatherService.weather(for:including: .current)`를 호출해 현재 기온, UV Index, 풍속과 풍향을 가져옵니다. `WeatherService.attribution`에서 받은 Apple Weather 마크와 법적 고지 링크도 상태 패널에 표시합니다.

WeatherKit 사용에는 Apple Developer Program 멤버십, WeatherKit이 활성화된 App ID, entitlement가 포함된 프로비저닝 프로파일이 필요합니다. 호출량과 출처 표시는 [WeatherKit 안내](https://developer.apple.com/weatherkit/)를 따릅니다.

Apple WeatherKit의 공개 `CurrentWeather`에는 PM2.5 원시 농도 필드가 없으므로 기온, UV Index, 풍속과 풍향만 담당합니다.

### Open-Meteo Air Quality REST API

PM2.5는 기존 REST 방식으로 아래 엔드포인트에 현재 좌표와 `current=pm2_5`만 전달합니다. 기온·UV·바람은 중복 요청하지 않습니다.

```text
https://air-quality-api.open-meteo.com/v1/air-quality
latitude={현재 위도}
longitude={현재 경도}
current=pm2_5
timezone=auto
```

`CombinedEnvironmentService`는 WeatherKit과 PM2.5 요청을 `async let`으로 병렬 실행합니다. 화면에는 Apple Weather 법적 고지와 함께 PM2.5 출처인 Open-Meteo 및 Copernicus CAMS 링크를 표시합니다.

## 빌드와 테스트

```bash
xcodebuild -project AirAR.xcodeproj \
  -scheme AirAR \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild -project AirAR.xcodeproj \
  -scheme AirAR \
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
  -project AirAR.xcodeproj \
  -scheme AirAR \
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

- 사용자가 위치 권한을 거부하거나 기기의 위치 서비스를 끄면 데이터를 조회할 수 없습니다.
- PM2.5는 현장 센서의 순간 측정값이 아니라 Open-Meteo가 제공하는 CAMS 모델 기반 현재값입니다.
- UV와 바람은 기기 센서의 순간 직접 측정값이 아니라 Apple Weather가 제공하는 현재 기상 조건입니다.
- 입자 수와 UV 오브젝트 크기는 학습을 위한 표현이며 공식 건강 기준이 아닙니다.
- 건강 또는 의료 판단에 사용하면 안 됩니다.
- AR 기능은 시뮬레이터가 아닌 실제 ARKit 지원 기기에서 확인해야 합니다.
- 네트워크가 없거나 API 형식이 달라지면 한국어 오류 메시지가 표시되며 하단 새로고침으로 다시 요청할 수 있습니다.
