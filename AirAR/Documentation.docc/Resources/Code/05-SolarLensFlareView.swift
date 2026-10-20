import QuartzCore
import UIKit

/// Renders the RealityKit sun position as a lens flare in screen space.
/// RealityKit의 태양 위치를 화면 공간의 렌즈 플레어로 표현합니다.
/// Creates halos, rays, and lens ghosts with Core Animation layers instead of image assets.
/// 이미지 에셋 대신 Core Animation 레이어로 헤일로, 방사광과 렌즈 고스트를 만듭니다.
@MainActor
final class SolarLensFlareView: UIView {
    // Allocate layers once and reuse them during frame updates instead of rebuilding the effect.
    // 효과를 매번 다시 만들지 않도록 레이어를 한 번 생성하고 프레임 갱신 때 재사용합니다.
    private let exposureLayer = CALayer()
    private let outerHaloLayer = CAGradientLayer()
    private let coreGlowLayer = CAGradientLayer()
    private let ringLayers = (0..<4).map { _ in CAShapeLayer() }
    private let rayLayers = (0..<32).map { _ in CAShapeLayer() }
    private let ghostLayers = (0..<7).map { _ in CAGradientLayer() }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        // Keep this decorative overlay from intercepting touches or becoming an accessibility element.
        // 장식용 오버레이가 터치를 가로채거나 접근성 요소가 되지 않도록 합니다.
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        backgroundColor = .clear
        configureLayers()
        setEffectOpacity(0)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Resizes the darkening layer to cover the entire view when its bounds change.
    /// 뷰 크기가 바뀌면 화면을 어둡게 하는 레이어가 전체 영역을 덮도록 조정합니다.
    override func layoutSubviews() {
        super.layoutSubviews()
        exposureLayer.frame = bounds
    }

    /// Updates all layers using the sun's screen position and camera alignment intensity.
    /// 태양이 화면에 보이는 위치와 카메라 정렬 강도로 모든 레이어를 갱신합니다.
    /// sunPosition uses view coordinates in points; intensity controls strength and phase drives periodic motion.
    /// sunPosition은 포인트 단위의 뷰 좌표이며, intensity는 효과 강도, phase는 주기적인 움직임을 제어합니다.
    func update(sunPosition: CGPoint?, intensity: Float, phase: Float) {
        // Hide the effect when projection is unavailable, intensity is negligible, or layout has no size.
        // 투영 좌표가 없거나 강도가 미미하거나 레이아웃 크기가 없으면 효과를 숨깁니다.
        guard let sunPosition, intensity > 0.001, !bounds.isEmpty else {
            hide()
            return
        }

        // Clamp intensity to 0...1 and scale visual dimensions relative to the shorter screen edge.
        // 강도를 0...1로 제한하고 화면의 짧은 변을 기준으로 효과 크기를 조절합니다.
        let strength = CGFloat(min(max(intensity, 0), 1))
        let minimumDimension = min(bounds.width, bounds.height)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        // The optical axis runs from the sun toward the screen center and guides ring and ghost placement.
        // 광학 축은 태양에서 화면 중심으로 향하며 링과 고스트를 배치하는 기준이 됩니다.
        var axis = CGPoint(x: center.x - sunPosition.x, y: center.y - sunPosition.y)
        let axisLength = hypot(axis.x, axis.y)
        let minimumAxisLength = minimumDimension * 0.24
        if axisLength < minimumAxisLength {
            // Keeps a short optical axis so ghosts do not overlap at one point when the sun is centered.
            // 태양이 정중앙에 있어도 고스트가 한 점에 겹치지 않도록 작은 광학 축을 유지합니다.
            let blend = 1 - axisLength / minimumAxisLength
            axis.x += minimumAxisLength * 0.54 * blend
            axis.y += minimumAxisLength * 0.84 * blend
        }

        // Disable implicit animations so layer properties follow each frame update immediately.
        // 레이어 속성이 매 프레임 갱신에 즉시 반영되도록 암시적 애니메이션을 끕니다.
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // Darken the background slightly as intensity rises to make the bright flare stand out.
        // 강도가 높아질수록 배경을 조금 어둡게 해 밝은 플레어가 두드러지게 합니다.
        exposureLayer.opacity = Float(0.24 * strength)
        place(
            outerHaloLayer,
            at: sunPosition,
            diameter: minimumDimension * (0.68 + 0.22 * strength)
        )
        outerHaloLayer.opacity = Float(0.84 * strength)

        place(
            coreGlowLayer,
            at: sunPosition,
            diameter: minimumDimension * (0.25 + 0.15 * strength)
        )
        coreGlowLayer.opacity = Float(min(0.45 + strength * 0.55, 1))

        updateRings(
            sunPosition: sunPosition,
            axis: axis,
            minimumDimension: minimumDimension,
            strength: strength,
            phase: CGFloat(phase)
        )
        updateRays(
            sunPosition: sunPosition,
            minimumDimension: minimumDimension,
            strength: strength,
            phase: CGFloat(phase)
        )
        updateGhosts(
            sunPosition: sunPosition,
            axis: axis,
            minimumDimension: minimumDimension,
            strength: strength
        )

        CATransaction.commit()
    }

    /// Hides all effect layers immediately while retaining them for later updates.
    /// 다음 갱신에 사용할 레이어를 유지하면서 모든 효과 레이어를 즉시 숨깁니다.
    func hide() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        setEffectOpacity(0)
        CATransaction.commit()
    }

    /// Adds layers from back to front: darkening, halo, rings, rays, ghosts, then the bright core.
    /// 뒤에서 앞으로 어둡게 하기, 헤일로, 링, 방사광, 고스트, 중심광 순서로 레이어를 쌓습니다.
    private func configureLayers() {
        exposureLayer.backgroundColor = UIColor.black.cgColor
        layer.addSublayer(exposureLayer)

        configureRadialGradient(
            outerHaloLayer,
            colors: [
                UIColor(red: 1, green: 0.99, blue: 0.88, alpha: 0.78),
                UIColor(red: 1, green: 0.76, blue: 0.30, alpha: 0.34),
                UIColor(red: 1, green: 0.55, blue: 0.10, alpha: 0)
            ],
            locations: [0, 0.28, 1]
        )
        layer.addSublayer(outerHaloLayer)

        ringLayers.enumerated().forEach { index, ring in
            ring.fillColor = UIColor.clear.cgColor
            ring.lineWidth = index == 0 ? 2.0 : 1.2
            ring.strokeColor = [
                UIColor(red: 1, green: 0.92, blue: 0.62, alpha: 0.60),
                UIColor(red: 0.45, green: 0.88, blue: 1, alpha: 0.38),
                UIColor(red: 1, green: 0.55, blue: 0.73, alpha: 0.34),
                UIColor(red: 0.38, green: 0.84, blue: 1, alpha: 0.28)
            ][index].cgColor
            layer.addSublayer(ring)
        }

        rayLayers.enumerated().forEach { index, ray in
            ray.fillColor = UIColor.clear.cgColor
            ray.strokeColor = UIColor(
                red: 1,
                green: 0.94,
                blue: 0.72,
                alpha: index.isMultiple(of: 4) ? 0.58 : 0.28
            ).cgColor
            ray.lineCap = .round
            ray.lineWidth = index.isMultiple(of: 4) ? 2.3 : 0.85
            layer.addSublayer(ray)
        }

        ghostLayers.enumerated().forEach { index, ghost in
            let tint: UIColor = index.isMultiple(of: 2)
                ? UIColor(red: 0.24, green: 0.88, blue: 1, alpha: 0.46)
                : UIColor(red: 1, green: 0.48, blue: 0.72, alpha: 0.40)
            configureRadialGradient(
                ghost,
                colors: [
                    UIColor.white.withAlphaComponent(0.82),
                    tint.withAlphaComponent(0.62),
                    tint.withAlphaComponent(0)
                ],
                locations: [0, 0.28, 1]
            )
            ghost.borderWidth = index == ghostLayers.count - 1 ? 1.8 : 1.0
            ghost.borderColor = tint.withAlphaComponent(index == ghostLayers.count - 1 ? 0.58 : 0.42).cgColor
            layer.addSublayer(ghost)
        }

        configureRadialGradient(
            coreGlowLayer,
            colors: [
                UIColor.white,
                UIColor(red: 1, green: 0.99, blue: 0.83, alpha: 1),
                UIColor(red: 1, green: 0.74, blue: 0.26, alpha: 0.64),
                UIColor(red: 1, green: 0.48, blue: 0.08, alpha: 0)
            ],
            locations: [0, 0.16, 0.48, 1]
        )
        layer.addSublayer(coreGlowLayer)
    }

    /// Configures a center-out radial gradient using normalized layer coordinates.
    /// 정규화된 레이어 좌표로 중심에서 바깥으로 퍼지는 방사형 그라디언트를 설정합니다.
    private func configureRadialGradient(
        _ gradient: CAGradientLayer,
        colors: [UIColor],
        locations: [NSNumber]
    ) {
        gradient.type = .radial
        gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.colors = colors.map(\.cgColor)
        gradient.locations = locations
    }

    /// Positions rings along the optical axis and adds a subtle periodic change in diameter.
    /// 광학 축을 따라 링을 배치하고 지름에 미세한 주기적 변화를 줍니다.
    private func updateRings(
        sunPosition: CGPoint,
        axis: CGPoint,
        minimumDimension: CGFloat,
        strength: CGFloat,
        phase: CGFloat
    ) {
        // These proportions are visual tuning values relative to the shorter screen edge.
        // 이 비율은 화면의 짧은 변을 기준으로 정한 시각적 조정값입니다.
        let diameters = [0.32, 0.50, 0.72, 0.94].map { minimumDimension * $0 }
        let offsets: [CGFloat] = [0, 0.16, 0.42, 0.74]

        for index in ringLayers.indices {
            let ring = ringLayers[index]
            let center = CGPoint(
                x: sunPosition.x + axis.x * offsets[index],
                y: sunPosition.y + axis.y * offsets[index]
            )
            let breathing = 1 + sin(phase * 0.45 + CGFloat(index)) * 0.012
            let diameter = diameters[index] * breathing
            ring.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
            ring.position = center
            ring.path = UIBezierPath(ovalIn: ring.bounds.insetBy(dx: 1, dy: 1)).cgPath
            ring.opacity = Float(strength * [0.86, 0.68, 0.52, 0.38][index])
        }
    }

    /// Distributes rays around the sun, with a stronger ray every fourth index.
    /// 태양 주위에 방사광을 배치하고 네 번째 인덱스마다 더 강한 광선을 만듭니다.
    private func updateRays(
        sunPosition: CGPoint,
        minimumDimension: CGFloat,
        strength: CGFloat,
        phase: CGFloat
    ) {
        for index in rayLayers.indices {
            let ray = rayLayers[index]
            ray.frame = bounds
            let angle = CGFloat(index) * 2 * .pi / CGFloat(rayLayers.count)
                + sin(phase * 0.12 + CGFloat(index) * 1.7) * 0.025
            // Use a deterministic index-based variation so ray lengths remain stable between frames.
            // 프레임 사이에서 광선 길이가 안정적으로 유지되도록 인덱스 기반의 일정한 변화를 사용합니다.
            let variation = CGFloat((index * 37) % 100) / 100
            let innerRadius = minimumDimension * (0.025 + variation * 0.018)
            let isMajorRay = index.isMultiple(of: 4)
            let baseLength = isMajorRay ? 0.66 : 0.25 + variation * 0.28
            let length = minimumDimension * baseLength * (0.82 + strength * 0.24)
            let direction = CGPoint(x: cos(angle), y: sin(angle))
            let path = UIBezierPath()
            path.move(to: CGPoint(
                x: sunPosition.x + direction.x * innerRadius,
                y: sunPosition.y + direction.y * innerRadius
            ))
            path.addLine(to: CGPoint(
                x: sunPosition.x + direction.x * length,
                y: sunPosition.y + direction.y * length
            ))
            ray.path = path.cgPath
            ray.opacity = Float(strength * (isMajorRay ? 0.88 : 0.44))
        }
    }

    /// Places colored lens ghosts along the optical axis at tuned sizes and opacities.
    /// 광학 축을 따라 조정된 크기와 불투명도로 색이 있는 렌즈 고스트를 배치합니다.
    private func updateGhosts(
        sunPosition: CGPoint,
        axis: CGPoint,
        minimumDimension: CGFloat,
        strength: CGFloat
    ) {
        // On the unadjusted axis, a factor of 1 reaches the screen center; larger factors extend beyond it.
        // 보정 전 축에서 배율 1은 화면 중심에 도달하며, 더 큰 값은 중심 너머로 이어집니다.
        let factors: [CGFloat] = [0.42, 0.70, 0.98, 1.24, 1.52, 1.82, 2.12]
        let diameters: [CGFloat] = [0.13, 0.060, 0.20, 0.078, 0.26, 0.095, 0.42]
        let opacities: [CGFloat] = [0.92, 0.78, 0.74, 0.82, 0.64, 0.76, 0.54]

        for index in ghostLayers.indices {
            let position = CGPoint(
                x: sunPosition.x + axis.x * factors[index],
                y: sunPosition.y + axis.y * factors[index]
            )
            place(
                ghostLayers[index],
                at: position,
                diameter: minimumDimension * diameters[index]
            )
            ghostLayers[index].opacity = Float(strength * opacities[index])
        }
    }

    /// Centers a circular layer using bounds and position, then rounds its corners to half its diameter.
    /// bounds와 position으로 원형 레이어를 배치하고 모서리 반경을 지름의 절반으로 설정합니다.
    private func place(_ layer: CALayer, at center: CGPoint, diameter: CGFloat) {
        layer.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        layer.position = center
        layer.cornerRadius = diameter * 0.5
    }

    /// Applies a shared opacity to every layer in the effect.
    /// 효과를 구성하는 모든 레이어에 공통 불투명도를 적용합니다.
    private func setEffectOpacity(_ opacity: Float) {
        exposureLayer.opacity = opacity
        outerHaloLayer.opacity = opacity
        coreGlowLayer.opacity = opacity
        ringLayers.forEach { $0.opacity = opacity }
        rayLayers.forEach { $0.opacity = opacity }
        ghostLayers.forEach { $0.opacity = opacity }
    }
}
