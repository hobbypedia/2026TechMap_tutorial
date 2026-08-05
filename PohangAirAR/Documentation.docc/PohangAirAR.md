# ``PohangAirAR``

포항의 기온, PM2.5와 UV Index를 가져와 사용자의 실제 공간에 시각화하는 과정을 배웁니다.

@Metadata {
    @PageImage(purpose: icon, source: "pohang-air-ar-hero.svg", alt: "AR 프레임 안의 미세먼지 입자와 태양 개념도")
    @PageColor(blue)
}

## 개요

PohangAirAR는 포항시청 중심 좌표의 Open-Meteo 데이터를 URLSession으로 요청하고 SwiftUI 상태로 표시합니다. ARKit은 기기의 6DoF 위치와 방향을 추적하며, RealityKit은 최초 사용자 위치를 기준으로 황토색 먼지를 360° 공간에 분포시키고, 같은 공간의 머리 위 한 지점에서 UV 스펙트럼이 아래로 퍼지게 합니다. 오브젝트는 화면에 고정되지 않으며 기기를 회전하면 월드 공간에 놓인 효과를 다른 방향에서 계속 보게 됩니다.

![AR 프레임 안에 PM2.5 입자와 UV 태양이 있는 구현 구조 개념도](pohang-air-ar-hero.svg)

## 학습 목표

- DTO와 도메인 모델을 분리해 HTTPS API를 요청합니다.
- `@MainActor` ViewModel에서 로딩, 성공, 실패, 취소를 관리합니다.
- 최초 카메라 자세에서 중력 정렬 월드 앵커를 만들고 오브젝트를 실제 공간에 고정합니다.
- 미세먼지를 사용자 주변 360°에 배치해 회전 방향마다 비슷한 밀도를 유지합니다.
- UV 광원을 사용자 위 한 지점에 고정하고 그 지점에서 8방향으로 내려오는 경사 평면으로 여러 방향에서 보이게 합니다.
- PM2.5 값에 따라 투명 먼지의 양과 부유 움직임을 바꿉니다.
- UV Index에 따라 에너지 오브젝트의 크기와 광량을 바꿉니다.
- 데이터와 AR 추적이 준비되면 시각화를 자동 배치합니다.

## 전체 데이터 흐름

```text
Open-Meteo → Service → ViewModel → SwiftUI → RealityKit Entity → Gravity-aligned World Anchor
```

## 실제 기기가 필요한 이유

AR 월드 트래킹은 실제 카메라 영상과 모션 센서의 결합이 필요합니다. 시뮬레이터에서는 코드 컴파일과 일반 UI 테스트만 수행하고, 카메라 권한·추적 안정화·월드 공간 배치는 ARKit 지원 iPhone 또는 iPad에서 확인합니다.

## 개인정보와 권한

고정 좌표를 요청하므로 사용자의 위치를 수집하지 않고 위치 권한도 요청하지 않습니다. 카메라는 AR 세션에만 사용하며 영상은 앱이 저장하거나 서버로 전송하지 않습니다.

## Topics

### 튜토리얼

- <doc:PohangAirARTutorial>
- <doc:Building-Pohang-Air-AR>

### 데이터와 상태

- ``AirQualitySnapshot``
- ``AirQualityServiceProtocol``
- ``OpenMeteoAirQualityService``
- ``AirQualityViewModel``

### AR 시각화

- ``AirQualityARView``
- ``ARSessionState``
- ``AirQualityEntityFactory``
- ``AirQualityVisualizationMapper``
