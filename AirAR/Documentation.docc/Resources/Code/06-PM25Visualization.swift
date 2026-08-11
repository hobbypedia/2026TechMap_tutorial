func makeDustEmitter(from snapshot: AirQualitySnapshot) -> Entity {
    let entity = Entity()
    entity.name = "PM25DustEmitter"

    let radians = Float(snapshot.windDirection * .pi / 180)
    let travelDirection = SIMD2<Float>(-sin(radians), cos(radians))
    let visualWindSpeed = min(max(Float(snapshot.windSpeed), 0) * 0.035, 0.65)

    var component = ParticleEmitterComponent()
    component.emitterShape = .box
    component.birthLocation = .volume
    component.birthDirection = .local
    component.emitterShapeSize = [5.8, 1.8, 5.8]
    component.emissionDirection = [travelDirection.x, 0.04, travelDirection.y]
    component.speed = max(visualWindSpeed, 0.025)
    component.speedVariation = max(component.speed * 0.45, 0.015)
    component.timing = .repeating(warmUp: 2.5, emit: .init(duration: 1))

    var particles = component.mainEmitter
    particles.birthRate = dustBirthRate(forPM25: snapshot.pm25)
    particles.birthRateVariation = particles.birthRate * 0.12
    particles.lifeSpan = 5.5
    particles.lifeSpanVariation = 1.3
    particles.size = 0.020
    particles.sizeVariation = 0.012
    particles.billboardMode = .billboard
    particles.opacityCurve = .gradualFadeInOut
    particles.noiseStrength = 0.11
    particles.noiseScale = 0.72
    particles.noiseAnimationSpeed = 0.16
    particles.blendMode = .alpha
    particles.color = .evolving(
        start: .random(
            a: UIColor(red: 0.52, green: 0.42, blue: 0.24, alpha: 0.18),
            b: UIColor(red: 0.82, green: 0.69, blue: 0.42, alpha: 0.34)
        ),
        end: .single(UIColor(red: 0.63, green: 0.52, blue: 0.31, alpha: 0))
    )
    component.mainEmitter = particles
    entity.components.set(component)
    return entity
}

func dustBirthRate(forPM25 value: Double) -> Float {
    let clampedValue = max(value, 0)
    if clampedValue >= 76 {
        return min(320 + Float(clampedValue - 76) * 0.65, 520)
    }
    return 35 + Float(clampedValue) * 3
}
