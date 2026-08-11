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
component.mainEmitter.lifeSpan = AirQualityVisualizationMapper.particleLifeSpan
component.mainEmitter.size = 0.05
component.mainEmitter.sizeVariation = 0.012
component.mainEmitter.billboardMode = .billboard
component.mainEmitter.opacityCurve = .gradualFadeInOut
component.mainEmitter.color = .constant(
    .single(UIColor(red: 0.76, green: 0.58, blue: 0.25, alpha: 0.42))
)

// image를 지정하지 않으므로 RealityKit의 기본 파티클 모양을 사용합니다.
emitterEntity.components.set(component)
dustField.addChild(emitterEntity)
