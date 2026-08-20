# ``AirAR``

현재 위치의 기온, PM2.5, UV Index와 지상 바람을 가져와 사용자의 실제 공간에 시각화하는 과정을 배웁니다.

@Metadata {
    @PageImage(purpose: icon, source: "air-ar-hero.svg", alt: "AR 프레임 안의 미세먼지 입자와 태양 개념도")
    @PageColor(blue)
}

## 개요

AirAR는 Core Location으로 허가받은 현재 좌표를 Open-Meteo Weather/Air Quality REST API에 전달합니다. ARKit은 중력과 북쪽을 기준으로 월드를 정렬하고, RealityKit은 황토색 먼지를 360° 공간에 분포시킨 뒤 현재 풍향과 풍속에 맞춰 이동시킵니다. 낮에는 Metal 셰이더 기반 태양과 빔이 머리 위에서 빛나고, 카메라가 태양을 향하면 렌즈 플레어가 나타납니다.

![AR 프레임 안에 PM2.5 입자와 UV 태양이 있는 구현 구조 개념도](air-ar-hero.svg)

## 학습 목표

- DTO와 도메인 모델을 분리해 HTTPS API를 요청합니다.
- `@MainActor` ViewModel에서 로딩, 성공, 실패, 취소를 관리합니다.
- 최초 카메라 위치에서 중력·북쪽 정렬 월드 앵커를 만들고 오브젝트를 실제 공간에 고정합니다.
- 미세먼지를 사용자 주변 360°에 배치해 회전 방향마다 비슷한 밀도를 유지합니다.
- 현지 일출·일몰 시각을 해석해 낮에만 태양과 UV 광선을 표시합니다.
- 이미지 에셋 없이 Metal 셰이더로 태양 코로나와 햇빛 빔을 만듭니다.
- 카메라가 태양을 향할 때 방사광과 렌즈 고스트를 화면에 합성합니다.
- PM2.5 값에 따라 투명 먼지의 양과 부유 움직임을 바꿉니다.
- 기상 풍향을 먼지 이동 방향으로 변환하고 풍속에 따라 이동 속도를 바꿉니다.
- UV Index에 따라 에너지 오브젝트의 크기와 광량을 바꿉니다.
- 데이터와 AR 추적이 준비되면 시각화를 자동 배치합니다.

## 전체 데이터 흐름

```text
Open-Meteo → Service → ViewModel → SwiftUI → RealityKit Entity → Gravity-and-heading World Anchor
```

## 실제 기기가 필요한 이유

AR 월드 트래킹은 실제 카메라 영상과 모션 센서의 결합이 필요합니다. 시뮬레이터에서는 코드 컴파일과 일반 UI 테스트만 수행하고, 카메라 권한·추적 안정화·월드 공간 배치는 ARKit 지원 iPhone 또는 iPad에서 확인합니다.

## 개인정보와 권한

앱은 실행 중 위치 권한을 요청하고 현재 좌표를 환경 데이터 조회에 사용합니다. 좌표를 앱 내부에 저장하지 않으며 카메라는 AR 세션에만 사용하고 영상은 앱이 저장하거나 서버로 전송하지 않습니다. 백그라운드 위치 기능이 없으므로 항상 허용 권한은 요청하지 않습니다.

## Topics

### 튜토리얼

- <doc:AirARTutorial>

### 데이터와 상태

- ``AirQualitySnapshot``
- ``UserLocation``
- ``AirQualityLevel``
- ``AirQualityServiceProtocol``
- ``LocationServiceProtocol``
- ``CoreLocationService``
- ``OpenMeteoAirQualityService``
- ``AirQualityViewModel``

### AR 시각화

- ``AirQualityARView``
- ``ARSessionState``
- ``AirQualityEntityFactory``
- ``AirQualityVisualizationMapper``
