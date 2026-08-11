import QuartzCore
import UIKit

/// RealityKit의 태양 위치를 화면 공간의 렌즈 플레어로 표현합니다.
/// 이미지 에셋 대신 Core Animation 레이어로 헤일로, 방사광과 렌즈 고스트를 만듭니다.
@MainActor
final class SolarLensFlareView: UIView {
    private let exposureLayer = CALayer()
    private let outerHaloLayer = CAGradientLayer()
    private let coreGlowLayer = CAGradientLayer()
    private let ringLayers = (0..<3).map { _ in CAShapeLayer() }
    private let rayLayers = (0..<18).map { _ in CAShapeLayer() }
    private let ghostLayers = (0..<5).map { _ in CAGradientLayer() }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
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

    override func layoutSubviews() {
        super.layoutSubviews()
        exposureLayer.frame = bounds
    }

    /// 태양이 화면에 보이는 위치와 카메라 정렬 강도로 모든 레이어를 갱신합니다.
    func update(sunPosition: CGPoint?, intensity: Float, phase: Float) {
        guard let sunPosition, intensity > 0.001, !bounds.isEmpty else {
            hide()
            return
        }

        let strength = CGFloat(min(max(intensity, 0), 1))
        let minimumDimension = min(bounds.width, bounds.height)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        var axis = CGPoint(x: center.x - sunPosition.x, y: center.y - sunPosition.y)
        let axisLength = hypot(axis.x, axis.y)
        let minimumAxisLength = minimumDimension * 0.24
        if axisLength < minimumAxisLength {
            // 태양이 정중앙에 있어도 고스트가 한 점에 겹치지 않도록 작은 광학 축을 유지합니다.
            let blend = 1 - axisLength / minimumAxisLength
            axis.x += minimumAxisLength * 0.54 * blend
            axis.y += minimumAxisLength * 0.84 * blend
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        exposureLayer.opacity = Float(0.19 * strength)
        place(
            outerHaloLayer,
            at: sunPosition,
            diameter: minimumDimension * (0.56 + 0.18 * strength)
        )
        outerHaloLayer.opacity = Float(0.84 * strength)

        place(
            coreGlowLayer,
            at: sunPosition,
            diameter: minimumDimension * (0.22 + 0.12 * strength)
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

    func hide() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        setEffectOpacity(0)
        CATransaction.commit()
    }

    private func configureLayers() {
        exposureLayer.backgroundColor = UIColor.black.cgColor
        layer.addSublayer(exposureLayer)

        configureRadialGradient(
            outerHaloLayer,
            colors: [
                UIColor(red: 0.90, green: 0.97, blue: 1, alpha: 0.62),
                UIColor(red: 0.37, green: 0.78, blue: 1, alpha: 0.25),
                UIColor(red: 0.28, green: 0.62, blue: 1, alpha: 0)
            ],
            locations: [0, 0.28, 1]
        )
        layer.addSublayer(outerHaloLayer)

        ringLayers.enumerated().forEach { index, ring in
            ring.fillColor = UIColor.clear.cgColor
            ring.lineWidth = index == 0 ? 1.6 : 1.0
            ring.strokeColor = [
                UIColor(red: 0.55, green: 0.92, blue: 1, alpha: 0.42),
                UIColor(red: 1, green: 0.58, blue: 0.78, alpha: 0.28),
                UIColor(red: 0.42, green: 0.84, blue: 1, alpha: 0.22)
            ][index].cgColor
            layer.addSublayer(ring)
        }

        rayLayers.enumerated().forEach { index, ray in
            ray.fillColor = UIColor.clear.cgColor
            ray.strokeColor = UIColor(
                red: 0.82,
                green: 0.95,
                blue: 1,
                alpha: index.isMultiple(of: 3) ? 0.34 : 0.18
            ).cgColor
            ray.lineCap = .round
            ray.lineWidth = index.isMultiple(of: 5) ? 1.6 : 0.7
            layer.addSublayer(ray)
        }

        ghostLayers.enumerated().forEach { index, ghost in
            let tint: UIColor = index.isMultiple(of: 2)
                ? UIColor(red: 0.32, green: 0.93, blue: 1, alpha: 0.32)
                : UIColor(red: 1, green: 0.55, blue: 0.78, alpha: 0.26)
            configureRadialGradient(
                ghost,
                colors: [
                    UIColor.white.withAlphaComponent(0.66),
                    tint.withAlphaComponent(0.48),
                    tint.withAlphaComponent(0)
                ],
                locations: [0, 0.28, 1]
            )
            ghost.borderWidth = index == ghostLayers.count - 1 ? 1.4 : 0.8
            ghost.borderColor = tint.withAlphaComponent(index == ghostLayers.count - 1 ? 0.42 : 0.30).cgColor
            layer.addSublayer(ghost)
        }

        configureRadialGradient(
            coreGlowLayer,
            colors: [
                UIColor.white,
                UIColor(red: 1, green: 0.97, blue: 0.82, alpha: 0.96),
                UIColor(red: 0.52, green: 0.86, blue: 1, alpha: 0.48),
                UIColor(red: 0.42, green: 0.78, blue: 1, alpha: 0)
            ],
            locations: [0, 0.16, 0.48, 1]
        )
        layer.addSublayer(coreGlowLayer)
    }

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

    private func updateRings(
        sunPosition: CGPoint,
        axis: CGPoint,
        minimumDimension: CGFloat,
        strength: CGFloat,
        phase: CGFloat
    ) {
        let diameters = [0.34, 0.56, 0.78].map { minimumDimension * $0 }
        let offsets: [CGFloat] = [0, 0.12, 0.38]

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
            ring.opacity = Float(strength * [0.72, 0.50, 0.38][index])
        }
    }

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
            let variation = CGFloat((index * 37) % 100) / 100
            let innerRadius = minimumDimension * (0.045 + variation * 0.025)
            let length = minimumDimension * (0.23 + variation * 0.34) * (0.8 + strength * 0.2)
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
            ray.opacity = Float(strength * (index.isMultiple(of: 3) ? 0.62 : 0.32))
        }
    }

    private func updateGhosts(
        sunPosition: CGPoint,
        axis: CGPoint,
        minimumDimension: CGFloat,
        strength: CGFloat
    ) {
        let factors: [CGFloat] = [0.52, 0.92, 1.28, 1.62, 1.96]
        let diameters: [CGFloat] = [0.11, 0.055, 0.18, 0.072, 0.38]
        let opacities: [CGFloat] = [0.80, 0.66, 0.58, 0.70, 0.40]

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

    private func place(_ layer: CALayer, at center: CGPoint, diameter: CGFloat) {
        layer.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        layer.position = center
        layer.cornerRadius = diameter * 0.5
    }

    private func setEffectOpacity(_ opacity: Float) {
        exposureLayer.opacity = opacity
        outerHaloLayer.opacity = opacity
        coreGlowLayer.opacity = opacity
        ringLayers.forEach { $0.opacity = opacity }
        rayLayers.forEach { $0.opacity = opacity }
        ghostLayers.forEach { $0.opacity = opacity }
    }
}
