# AirAR

기기의 현재 위치를 Open-Meteo REST API에 전달해 기온, PM2.5, UV Index, 지상 풍속·풍향을 받아오고 RealityKit으로 공간에 시각화하는 iOS 17 교육용 앱입니다.

> AR 기능은 카메라와 6DoF 월드 트래킹이 필요합니다. 시뮬레이터가 아닌 ARKit 지원 iPhone 또는 iPad에서 최종 확인하세요.

## 완성 화면과 사용자 흐름

앱을 열면 상단에 `온도 | 미세먼지 | UV`가 표시됩니다. 황토색 먼지는 PM2.5 농도에 따라 최초 사용자 위치의 360° 주변에 분포하고, 바람이 불어가는 방향으로 흐릅니다. 이미지 없이 Metal 셰이더가 그린 UV 빔은 그 위치 위쪽의 월드 좌표에 고정됩니다.

## 기술 스택

- Swift 5, SwiftUI, async/await, URLSession, Codable
- Open-Meteo Weather Forecast API와 Air Quality API
- ARKit `ARWorldTrackingConfiguration`, RealityKit `ARView`와 `CustomMaterial`
- Metal surface shader를 이용한 절차적 UV 빔 렌더링
- iOS 17.0 이상, Xcode 15 이상
- XCTest, DocC, GitHub Actions와 GitHub Pages

## 데이터 흐름

```text
Core Location → 현재 좌표/지역 이름
                 ├─ GET /v1/forecast → 기온·풍속·풍향
                 └─ GET /v1/air-quality → PM2.5·UV
                                      ↓
                         OpenMeteoEnvironmentService
                                      ↓
                           AirQualitySnapshot
                                      ↓
              AirQualityViewModel → SwiftUI + RealityKit
```

두 요청은 `async let`으로 동시에 실행됩니다. 서버의 JSON 구조는 `OpenMeteoWeatherResponse`와 `OpenMeteoAirQualityResponse`가 담당하고, 화면과 AR은 API 형식을 모르는 `AirQualitySnapshot`만 사용합니다.

## 이미지 없이 UV 빔 그리기

UV 시각화는 PNG 텍스처를 사용하지 않습니다. RealityKit 평면의 0...1 `UV` 좌표를 Metal surface shader가 읽어 중앙에서 아래로 넓어지는 마스크를 만들고, 가로 위치를 스펙트럼 색으로 변환합니다. Swift는 `CustomMaterial.custom.value`를 통해 정규화된 UV Index와 투명도를 셰이더에 전달합니다. 따라서 UV 수치가 높을수록 빔이 커지고 선명해지며, 에셋을 교체하지 않아도 수식만으로 모양과 색을 조절할 수 있습니다.

셰이더는 RealityKit이 제공하는 시간 값으로 아주 약한 떨림도 계산합니다. Metal 라이브러리를 불러오지 못하는 환경에서는 단색 `UnlitMaterial`로 대체되어 AR 오브젝트 자체는 계속 표시됩니다.

## API와 REST API

API(Application Programming Interface)는 한 프로그램이 다른 프로그램의 기능이나 데이터를 정해진 규칙으로 요청하는 접점입니다. 식당에서 주문서의 메뉴 이름과 형식을 지켜 요청하듯, 앱은 API 문서가 정한 주소와 매개변수로 요청하고 약속된 형식의 응답을 받습니다.

REST는 웹의 자원을 HTTP 방식으로 다루는 API 설계 스타일입니다. 이 앱에서 쓰는 REST API 요청은 다음 요소로 읽을 수 있습니다.

- **엔드포인트(endpoint)**: 요청을 받을 서버 자원의 HTTPS 주소
- **HTTP 메서드**: 데이터를 조회한다는 뜻의 `GET`
- **쿼리 매개변수(query parameter)**: `?` 뒤에 붙는 위도, 경도, 필요한 변수
- **상태 코드(status code)**: `200...299`는 성공, `400` 또는 `500` 계열은 오류
- **응답 본문(response body)**: 앱이 `Decodable`로 변환할 JSON 데이터

따라서 “URL로 가져온다”와 “API로 가져온다”는 서로 반대되는 말이 아닙니다. REST API도 URL을 **API 엔드포인트 주소**로 사용합니다. 웹 페이지를 내려받는 대신 그 주소에 HTTP 요청을 보내 JSON 데이터를 받는 것이 차이입니다.

## 이 앱이 호출하는 두 REST API

### 1. 기상 API

```text
GET https://api.open-meteo.com/v1/forecast
    ?latitude={현재 위도}
    &longitude={현재 경도}
    &current=temperature_2m,wind_speed_10m,wind_direction_10m
    &wind_speed_unit=ms
    &timezone=auto
```

- `temperature_2m`: 지상 2m 기온(°C)
- `wind_speed_10m`: 지상 10m 풍속(`wind_speed_unit=ms`이므로 m/s)
- `wind_direction_10m`: 북쪽 0° 기준 풍향

### 2. 대기질 API

```text
GET https://air-quality-api.open-meteo.com/v1/air-quality
    ?latitude={현재 위도}
    &longitude={현재 경도}
    &current=pm2_5,uv_index
    &timezone=auto
```

- `pm2_5`: PM2.5 농도(μg/m³)
- `uv_index`: 구름을 고려한 UV Index

Open-Meteo의 공개 비상업용 API는 이 요청에서 API 키가 필수가 아니지만, 실제 서비스 배포 전에는 반드시 [가격·이용 조건](https://open-meteo.com/en/pricing)과 [라이선스](https://open-meteo.com/en/licence)를 확인해야 합니다. 대기질 값은 현장 측정기에서 직접 읽는 값이 아니라 Copernicus CAMS 모델 기반 값이므로 화면에 Open-Meteo와 CAMS 출처 링크를 표시합니다.

공식 문서: [Weather Forecast API](https://open-meteo.com/en/docs), [Air Quality API](https://open-meteo.com/en/docs/air-quality-api)

## Swift에서 요청하는 순서

1. `URLComponents`에 엔드포인트를 넣습니다.
2. `URLQueryItem`으로 좌표와 변수 이름을 추가합니다. 문자열을 직접 이어 붙이지 않아 인코딩 실수를 줄입니다.
3. `URLSession.data(from:)`으로 비동기 `GET` 요청을 보냅니다.
4. `HTTPURLResponse.statusCode`가 `200...299`인지 검사합니다.
5. `JSONDecoder`로 JSON을 응답 DTO로 변환합니다.
6. 두 API 결과를 `AirQualitySnapshot` 하나로 조합합니다.
7. 취소, 네트워크, HTTP, 디코딩 오류를 화면용 오류로 변환합니다.

예를 들어 서버의 `pm2_5`는 Swift 이름 규칙에 맞는 `pm25`로 매핑합니다.

```swift
struct Current: Decodable {
    let pm25: Double

    enum CodingKeys: String, CodingKey {
        case pm25 = "pm2_5"
    }
}
```

## 프로젝트 구조

```text
AirAR/
├── App/
├── Models/                 # 도메인 모델과 REST 응답 DTO
├── Services/               # 위치와 Open-Meteo 요청
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
```

## 실행 요구사항과 권한

1. `AirAR.xcodeproj`를 Xcode에서 엽니다.
2. AirAR Target의 Signing Team을 선택합니다.
3. iOS 17 이상을 실행하는 ARKit 지원 실제 기기를 연결합니다.
4. 앱을 실행하고 `앱을 사용하는 동안` 위치 권한과 카메라 권한을 허용합니다.
5. 주변을 천천히 비추면 정상 추적 상태에서 시각화가 자동 배치됩니다.

위치는 현재 지역의 환경 데이터를 조회하는 데만 사용하고, 카메라는 데이터를 주변 공간에 표시하는 데만 사용합니다. 백그라운드 위치와 `항상 허용` 권한은 요청하지 않습니다.

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

서비스 단위 테스트는 `URLProtocol` 스텁을 사용하므로 실제 네트워크 없이 성공 응답, HTTP 오류, 잘못된 JSON, 취소를 재현합니다. 시뮬레이터 이름은 `xcrun simctl list devices available` 결과에 맞게 바꿉니다.

## DocC 빌드

```bash
xcodebuild docbuild \
  -project AirAR.xcodeproj \
  -scheme AirAR \
  -destination 'generic/platform=iOS' \
  -derivedDataPath ./DerivedData \
  CODE_SIGNING_ALLOWED=NO
```

Xcode의 Product → Build Documentation으로도 단계별 튜토리얼을 열 수 있습니다.

## 에셋과 GitHub Pages

`python3 Scripts/generate_assets.py`를 실행하면 앱 아이콘과 DocC 개념도를 다시 생성합니다. `main`에 Push하면 `.github/workflows/deploy-docc.yml`이 DocC를 GitHub Pages 형식으로 빌드합니다. 저장소 Settings → Pages의 Source는 **GitHub Actions**로 설정합니다.

## 알려진 제한사항

- 위치 권한이 없거나 네트워크가 끊기면 데이터를 조회할 수 없습니다.
- PM2.5는 Open-Meteo가 제공하는 CAMS 모델 기반 값이며 현장 센서의 순간 측정값이 아닙니다.
- 기온, UV, 바람도 기기 센서의 직접 측정값이 아니라 수치 모델 기반 현재 조건입니다.
- Open-Meteo 이용 조건과 API 형식은 바뀔 수 있으므로 배포 전에 최신 공식 문서를 확인해야 합니다.
- 입자 수와 UV 오브젝트 크기는 학습을 위한 표현이며 건강 또는 의료 판단에 사용하면 안 됩니다.
- AR 기능은 실제 ARKit 지원 기기에서 확인해야 합니다.
