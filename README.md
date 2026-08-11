# AirAR

기기의 현재 위치에서 기온, PM2.5, UV Index와 지상 풍속·풍향을 Open-Meteo로 조회하고, 최초 사용자 위치를 중심으로 북쪽 정렬 월드 공간에 RealityKit 시각화를 배치하는 iOS 18 교육용 앱입니다.

> 이 앱의 AR 기능은 카메라와 6DoF 월드 트래킹이 필요한 기능입니다. 시뮬레이터가 아닌 ARKit 지원 iPhone 또는 iPad에서 최종 확인해야 합니다.

## 완성 화면과 사용자 흐름

앱을 열면 상단에 `온도 | 미세먼지 | UV`가 한 줄로 표시됩니다. 데이터와 공간 추적이 준비되면 황토색 먼지는 최초 사용자 위치의 360° 주변에 분포하고 현재 풍향의 반대쪽으로 흘러가며, UV 스펙트럼은 그 위치 위쪽의 한 월드 지점에서 아래로 퍼집니다. 기기를 회전해도 화면에 붙은 HUD처럼 따라오는 대신 실제 공간에 고정된 시각화를 다른 방향에서 계속 볼 수 있습니다. PM2.5가 심각 수준이면 입자 수와 분포 면적이 크게 늘어나고, 풍속이 강할수록 먼지가 빠르게 이동하며, UV Index가 높을수록 광선 불투명도가 올라갑니다.

## 기술 스택

- Swift 5, SwiftUI, async/await, URLSession
- ARKit `ARWorldTrackingConfiguration`, RealityKit `ARView`와 `ParticleEmitterComponent`
- iOS 18.0 이상, Xcode 16 이상
- XCTest, DocC, GitHub Actions와 GitHub Pages

## 아키텍처

```text
Core Location → 현재 좌표/지역 이름
Open-Meteo Weather + Air Quality API
→ OpenMeteoAirQualityService
→ AirQualityViewModel
→ SwiftUI 오버레이
→ AirQualityEntityFactory
→ 중력·북쪽 정렬 월드 앵커
```

API 응답 DTO와 앱의 `AirQualitySnapshot`을 분리했습니다. `AirQualityViewModel`은 로딩 상태뿐 아니라 화면에 표시할 포맷과 5단계 환경 상태까지 제공하며, View는 표시만 담당합니다. AR 시각화 생성률과 정규화는 `AirQualityVisualizationMapper`에 순수 함수로 분리해 기기나 RealityKit 없이 테스트할 수 있습니다.

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
2. AirAR Target의 Signing Team을 선택합니다.
3. iOS 18 이상을 실행하는 ARKit 지원 실제 기기를 연결합니다.
4. 앱을 실행하고 `앱을 사용하는 동안` 위치 권한과 카메라 권한을 허용합니다.
5. 주변을 천천히 비추면 정상 추적 상태에서 시각화가 자동으로 배치됩니다.

위치는 현재 지역의 환경 데이터를 조회하는 데만 사용하고, 카메라는 그 데이터를 주변 공간에 증강현실로 표시하는 데만 사용합니다. 첫 위치 요청에서는 iOS 표준 권한 창이 표시되며, 거부한 경우 앱의 `위치 설정 열기` 버튼으로 설정을 다시 열 수 있습니다. 백그라운드 위치를 사용하지 않으므로 `항상 허용` 권한은 요청하지 않습니다.

## API

요청 주소는 `URLComponents`와 `URLQueryItem`으로 구성하며 API Key가 필요하지 않습니다. URL은 REST API의 엔드포인트이고, 앱은 `URLSession`으로 JSON을 받아 해석합니다. 좌표와 시간대는 현재 위치에 맞춰 매 요청마다 바뀝니다.

```text
https://air-quality-api.open-meteo.com/v1/air-quality
latitude={현재 위도}
longitude={현재 경도}
current=pm2_5,uv_index
timezone=auto

https://api.open-meteo.com/v1/forecast
latitude={현재 위도}
longitude={현재 경도}
current=temperature_2m,wind_speed_10m,wind_direction_10m
wind_speed_unit=ms
timezone=auto
```

Open-Meteo의 무료 Open-Access 계층은 비상업적 사용에 제공되며 API Key가 필요하지 않습니다. 배포 형태와 호출량이 달라질 경우 공식 이용 조건과 호출 한도를 다시 확인해야 합니다. Weather data by [Open-Meteo.com](https://open-meteo.com/), licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

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

표준 라이브러리만 사용하는 스크립트가 텍스트 없는 1024px 앱 아이콘과 DocC용 SVG 개념도를 생성합니다. PM2.5는 별도 이미지 없이 RealityKit의 기본 파티클 모양을 사용하며, `UVSpectrum` 투명 PNG는 앱과 DocC에서 함께 사용합니다.

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
- PM2.5, UV와 바람 데이터는 기기 센서나 현장 관측소의 순간 직접 측정값이 아니라 Open-Meteo가 제공하는 모델 기반 현재값입니다.
- 입자 수와 UV 오브젝트 크기는 학습을 위한 표현이며 공식 건강 기준이 아닙니다.
- 건강 또는 의료 판단에 사용하면 안 됩니다.
- AR 기능은 시뮬레이터가 아닌 실제 ARKit 지원 기기에서 확인해야 합니다.
- 네트워크가 없거나 API 형식이 달라지면 한국어 오류 메시지가 표시되며 하단 새로고침으로 다시 요청할 수 있습니다.
