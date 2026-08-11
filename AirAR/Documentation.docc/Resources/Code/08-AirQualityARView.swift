sceneUpdateSubscription = arView.scene.subscribe(
    to: SceneEvents.Update.self
) { [weak self] event in
    self?.animate(deltaTime: Float(event.deltaTime))
}

private func animate(deltaTime: Float) {
    elapsedTime += min(deltaTime, 0.1)
    let cameraPosition = arView.cameraTransform.translation

    for index in dustAnimations.indices {
        var item = dustAnimations[index]
        if let parent = item.entity.parent {
            let localCamera = parent.convert(position: cameraPosition, from: nil)
            let distance = simd_distance(localCamera, item.entity.position)
            let speed = AirQualityVisualizationMapper.animationSpeed(
                forDistance: distance,
                variation: item.speedVariation
            )
            let frameDuration = min(deltaTime, 0.1)
            item.localElapsedTime += frameDuration * speed
            item.windTravelDistance += frameDuration
                * windVisualSpeed
                * item.speedVariation

            var position = AirQualityVisualizationMapper.windDisplacedPosition(
                base: item.base,
                travelDistance: item.windTravelDistance,
                direction: windTravelDirection,
                fieldRadius: dustFieldRadius
            )
            position.x += sin(item.localElapsedTime * 0.55 + item.phase) * 0.018
            position.y += sin(item.localElapsedTime * 0.9 + item.phase * 1.7) * 0.025
            item.entity.position = position
            dustAnimations[index] = item

            let direction = localCamera - position
            if simd_length_squared(direction) > 0.0001 {
                item.entity.orientation = simd_quatf(
                    from: [0, 0, 1],
                    to: simd_normalize(direction)
                )
            }
        }
    }

    let pulse = 1 + sin(elapsedTime * 1.35) * 0.035
    uvSpectrums.forEach { spectrum in
        spectrum.scale = [pulse, pulse, pulse]
    }
}
