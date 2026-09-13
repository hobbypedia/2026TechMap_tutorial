import RealityKit
import UIKit

/// 4단계 체크포인트: 사용자 주변에 PM2.5 파티클을 만듭니다.
final class AirQualityEntityFactory {
    func makeVisualization(from snapshot: AirQualitySnapshot) -> Entity {
        let root = Entity()
        root.name = "AirQualityRootEntity"
        rebuild(root: root, snapshot: snapshot)
        return root
    }

    func updateVisualization(root: Entity, with snapshot: AirQualitySnapshot) {
        root.children.forEach { $0.removeFromParent() }
        rebuild(root: root, snapshot: snapshot)
    }

    private func rebuild(root: Entity, snapshot: AirQualitySnapshot) {
        root.addChild(makeDustField(snapshot: snapshot))
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
        component.timing = .repeating(emit: .init(duration: 1), idle: nil)

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
        emitterEntity.components.set(component)
        return emitterEntity
    }
}
