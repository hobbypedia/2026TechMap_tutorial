// 태양의 월드 좌표를 화면 좌표로 바꿉니다.
let sunPosition = sunEntity.position(relativeTo: nil)
let screenPosition = arView.project(sunPosition)

// 카메라의 -Z축이 바라보는 방향입니다.
let cameraTransform = frame.camera.transform
let cameraPosition = SIMD3<Float>(
    cameraTransform.columns.3.x,
    cameraTransform.columns.3.y,
    cameraTransform.columns.3.z
)
let cameraForward = -SIMD3<Float>(
    cameraTransform.columns.2.x,
    cameraTransform.columns.2.y,
    cameraTransform.columns.2.z
)

let alignment = solarFlareIntensity(
    cameraForward: cameraForward,
    directionToSun: sunPosition - cameraPosition
)

// UV가 강하고 태양을 정면으로 볼수록 화면 공간 효과가 강해집니다.
let uvBrightness = 0.58 + normalizedUV * 0.42
lensFlareView.update(
    sunPosition: screenPosition,
    intensity: alignment * uvBrightness,
    phase: elapsedTime
)

// SolarLensFlareView는 이미지 없이 Core Animation 레이어를 조합합니다.
// - CAGradientLayer: 태양 코어, 바깥 헤일로와 렌즈 고스트
// - CAShapeLayer: 동심원 3개와 방사광 18개
// - CALayer: 정면을 볼 때 주변 노출을 낮추는 검은 오버레이
// 태양이 화면 중앙에 있어도 고스트가 겹치지 않게 최소 광학 축을 유지합니다.
