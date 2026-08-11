# ``AirAR``

현재 위치의 기온·PM2.5·UV·바람·일출·일몰을 Open-Meteo REST API로 가져와 실제 공간에 시각화하는 과정을 배웁니다.

@Metadata {
    @PageImage(purpose: icon, source: "air-ar-hero.svg", alt: "AR 프레임 안의 미세먼지 입자와 태양 개념도")
    @PageColor(blue)
}

## 개요

AirAR는 현재 좌표를 Open-Meteo Weather Forecast API와 Air Quality API에 전달합니다. 두 HTTP `GET` 응답의 JSON을 하나의 도메인 모델로 합치고, RealityKit `ParticleEmitterComponent`는 PM2.5 먼지를 풍향에 맞춰 이동시키며 Metal 셰이더로 만든 햇빛과 발광 코로나를 사용자 위에 배치합니다. 태양을 올려다보면 화면 공간 렌즈 플레어가 나타납니다.

![AR 프레임 안에 PM2.5 입자와 UV 태양이 있는 구현 구조 개념도](air-ar-hero.svg)

## 학습 목표

- API, REST API, 엔드포인트, 쿼리 매개변수, HTTP 상태 코드와 JSON의 관계를 설명합니다.
- `URLComponents`, `URLSession`, `JSONDecoder`로 두 REST 엔드포인트를 병렬 요청합니다.
- 서버 응답 DTO와 앱의 도메인 모델을 분리합니다.
- `@MainActor` ViewModel에서 로딩, 성공, 실패, 취소를 관리합니다.
- 최초 카메라 위치에서 중력·북쪽 정렬 월드 앵커를 만들고 오브젝트를 실제 공간에 고정합니다.
- 이미지 에셋 없이 `ParticleEmitterComponent`로 사용자 주변에 미세먼지를 생성하고 회전 방향마다 비슷한 밀도를 유지합니다.
- 이미지 에셋 없이 RealityKit `CustomMaterial`과 Metal surface shader로 따뜻한 UV 햇빛과 태양 코로나의 모양, 색과 투명도를 만듭니다.
- 투명 평면 두 개만 직교시켜 여러 방향에서 보이면서도 색이 흰색으로 뭉치는 중첩을 줄입니다.
- 태양의 월드 좌표와 카메라 방향으로 헤일로, 방사광, 동심원과 렌즈 고스트의 강도와 간격을 계산합니다.
- PM2.5 값에 따라 투명 먼지의 양과 부유 움직임을 바꿉니다.
- 기상 풍향을 먼지 이동 방향으로 변환하고 풍속에 따라 이동 속도를 바꿉니다.
- UV Index에 따라 에너지 오브젝트의 크기와 광량을 바꿉니다.
- 조회 위치의 현지 일출·일몰을 절대 시각으로 변환하고 낮에만 태양·코로나·빔·렌즈 플레어를 표시합니다.
- 데이터와 AR 추적이 준비되면 시각화를 자동 배치합니다.

## 전체 데이터 흐름

```text
Open-Meteo Weather API ─────┐
                            ├→ OpenMeteoEnvironmentService
Open-Meteo Air Quality API ─┘  → ViewModel → SwiftUI → RealityKit
```

## 실제 기기가 필요한 이유

AR 월드 트래킹은 실제 카메라 영상과 모션 센서의 결합이 필요합니다. 시뮬레이터에서는 코드 컴파일과 일반 UI 테스트만 수행하고, 카메라 권한·추적 안정화·월드 공간 배치는 ARKit 지원 iPhone 또는 iPad에서 확인합니다.

## 개인정보와 권한

앱은 실행 중 위치 권한을 요청하고 현재 좌표를 환경 데이터 조회에 사용합니다. 좌표를 앱 내부에 저장하지 않으며 카메라는 AR 세션에만 사용하고 영상은 앱이 저장하거나 서버로 전송하지 않습니다. 백그라운드 위치 기능이 없으므로 항상 허용 권한은 요청하지 않습니다.

## Topics

### 튜토리얼

- <doc:AirARTutorial>
- <doc:Building-Air-AR>

### 데이터와 상태

- ``AirQualitySnapshot``
- ``UserLocation``
- ``AirQualityLevel``
- ``AirQualityServiceProtocol``
- ``LocationServiceProtocol``
- ``CoreLocationService``
- ``OpenMeteoWeatherResponse``
- ``OpenMeteoAirQualityResponse``
- ``OpenMeteoEnvironmentService``
- ``AirQualityViewModel``

### AR 시각화

- ``AirQualityARView``
- ``ARSessionState``
- ``AirQualityEntityFactory``
- ``AirQualityVisualizationMapper``
