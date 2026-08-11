import RealityKit
import UIKit

/// 수치표 대신 공기 중 먼지와 자외선 에너지 오브젝트를 생성합니다.
final class AirQualityEntityFactory {
    /// 환경 데이터 전체 시각화를 만듭니다.
    func makeVisualization(from snapshot: AirQualitySnapshot) -> Entity {
        let root = Entity()
        root.name = "AirQualityRootEntity"
        rebuild(root: root, snapshot: snapshot)
        return root
    }

    /// 기존 루트 엔티티를 새 데이터로 갱신합니다.
    func updateVisualization(root: Entity, with snapshot: AirQualitySnapshot) {
        root.children.forEach { $0.removeFromParent() }
        rebuild(root: root, snapshot: snapshot)
    }

    private func rebuild(root: Entity, snapshot: AirQualitySnapshot) {
        root.addChild(makeDustField(snapshot: snapshot))
        root.addChild(makeUVObject(snapshot: snapshot))
    }

    private func makeDustField(snapshot: AirQualitySnapshot) -> Entity {
        let emitterEntity = Entity()
        emitterEntity.name = "PM25ParticleEmitter"

        let radius = AirQualityVisualizationMapper.dustFieldRadius(forPM25: snapshot.pm25)
        let speed = AirQualityVisualizationMapper.visualWindSpeed(
            forMetersPerSecond: snapshot.windSpeed
        )
        var component = ParticleEmitterComponent()
        component.emitterShape = .sphere
        component.emitterShapeSize = [radius * 2, 1.6, radius * 2]
        component.birthLocation = .volume
        component.birthDirection = .world
        component.emissionDirection = AirQualityVisualizationMapper.emitterDirection(
            forMeteorologicalDegrees: snapshot.windDirection
        )
        component.speed = speed
        component.speedVariation = max(speed * 0.35, 0.02)
        component.timing = .repeating(
            emit: .init(duration: 1),
            idle: nil
        )

        component.mainEmitter.birthRate = AirQualityVisualizationMapper.particleBirthRate(
            forPM25: snapshot.pm25
        )
        component.mainEmitter.birthRateVariation = component.mainEmitter.birthRate * 0.12
        component.mainEmitter.lifeSpan = AirQualityVisualizationMapper.particleLifeSpan
        component.mainEmitter.lifeSpanVariation = 1.2
        component.mainEmitter.size = 0.05
        component.mainEmitter.sizeVariation = 0.012
        component.mainEmitter.billboardMode = .billboard
        component.mainEmitter.opacityCurve = .gradualFadeInOut
        component.mainEmitter.noiseStrength = 0.08
        component.mainEmitter.noiseScale = 0.65
        component.mainEmitter.noiseAnimationSpeed = 0.18
        component.mainEmitter.color = .constant(
            .single(UIColor(red: 0.76, green: 0.58, blue: 0.25, alpha: 0.42))
        )
        // image를 지정하지 않아 RealityKit의 기본 원형 파티클 텍스처를 사용합니다.
        emitterEntity.components.set(component)
        return emitterEntity
    }

    private func makeUVObject(snapshot: AirQualitySnapshot) -> Entity {
        let group = Entity()
        group.name = "UVGroup"
        group.position = [0, 0, 0]

        let normalized = AirQualityVisualizationMapper.normalizedUV(for: snapshot.uvIndex)
        let texture = try? TextureResource.load(named: "UVSpectrum")
        let opacity = AirQualityVisualizationMapper.uvOpacity(for: snapshot.uvIndex) * 0.35
        let material = makeUnlitMaterial(texture: texture, tint: .white, opacity: opacity)
        let size = 1.65 + normalized * 0.35
        let beamCount = 8
        let sourceHeight: Float = 1.45
        let radialOffset: Float = 0.6
        let halfHeight = size * 0.5
        let tilt = asin(min(radialOffset / halfHeight, 0.95))
        let centerHeight = sourceHeight - cos(tilt) * halfHeight

        for index in 0..<beamCount {
            let yaw = Float(index) * 2 * .pi / Float(beamCount)
            let yawRotation = simd_quatf(angle: yaw, axis: [0, 1, 0])
            let tiltRotation = simd_quatf(angle: tilt, axis: [1, 0, 0])
            let spectrum = ModelEntity(
                mesh: .generatePlane(width: size, height: size),
                materials: [material]
            )
            spectrum.name = "UVSpectrum-" + String(index)
            spectrum.position = yawRotation.act([0, centerHeight, -radialOffset])
            spectrum.orientation = yawRotation * tiltRotation
            group.addChild(spectrum)
        }

        return group
    }

    private func makeUnlitMaterial(
        texture: TextureResource?,
        tint: UIColor,
        opacity: Float
    ) -> UnlitMaterial {
        var material = UnlitMaterial()
        if let texture {
            material.color = .init(tint: tint, texture: .init(texture))
        } else {
            material.color = .init(tint: tint)
        }
        material.blending = .transparent(opacity: .init(floatLiteral: opacity))
        return material
    }

}
