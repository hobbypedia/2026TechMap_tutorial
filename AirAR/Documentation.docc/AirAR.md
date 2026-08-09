# ``AirAR``

현재 위치의 기온·UV·바람은 WeatherKit으로, PM2.5는 REST API로 가져와 실제 공간에 시각화하는 과정을 배웁니다.

@Metadata {
    @PageImage(purpose: icon, source: "air-ar-hero.svg", alt: "AR 프레임 안의 미세먼지 입자와 태양 개념도")
    @PageColor(blue)
}

## 개요

AirAR는 현재 좌표를 Apple WeatherKit과 Open-Meteo Air Quality API에 전달합니다. WeatherKit은 기온·UV·풍속·풍향을, Open-Meteo는 WeatherKit에 없는 PM2.5를 제공합니다. RealityKit은 PM2.5 먼지를 WeatherKit 풍향에 맞춰 이동시키고 UV 스펙트럼을 사용자 위에 배치합니다.

![AR 프레임 안에 PM2.5 입자와 UV 태양이 있는 구현 구조 개념도](air-ar-hero.svg)

## 학습 목표

- WeatherKit Swift API와 Open-Meteo REST API의 차이를 비교합니다.
- 두 데이터 소스를 병렬 요청해 하나의 도메인 모델로 결합합니다.
- `@MainActor` ViewModel에서 로딩, 성공, 실패, 취소를 관리합니다.
- 최초 카메라 위치에서 중력·북쪽 정렬 월드 앵커를 만들고 오브젝트를 실제 공간에 고정합니다.
- 미세먼지를 사용자 주변 360°에 배치해 회전 방향마다 비슷한 밀도를 유지합니다.
- UV 광원을 사용자 위 한 지점에 고정하고 그 지점에서 8방향으로 내려오는 경사 평면으로 여러 방향에서 보이게 합니다.
- PM2.5 값에 따라 투명 먼지의 양과 부유 움직임을 바꿉니다.
- 기상 풍향을 먼지 이동 방향으로 변환하고 풍속에 따라 이동 속도를 바꿉니다.
- UV Index에 따라 에너지 오브젝트의 크기와 광량을 바꿉니다.
- 데이터와 AR 추적이 준비되면 시각화를 자동 배치합니다.

## 전체 데이터 흐름

```text
WeatherKit ─┐
            ├→ Combined Service → ViewModel → SwiftUI → RealityKit
Open-Meteo ─┘
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
- ``WeatherKitEnvironmentService``
- ``OpenMeteoPM25Provider``
- ``CombinedEnvironmentService``
- ``AirQualityViewModel``

### AR 시각화

- ``AirQualityARView``
- ``ARSessionState``
- ``AirQualityEntityFactory``
- ``AirQualityVisualizationMapper``
