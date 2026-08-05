sceneUpdateSubscription = arView.scene.subscribe(
    to: SceneEvents.Update.self
) { [weak self] event in
    self?.animate(deltaTime: Float(event.deltaTime))
}

private func animate(deltaTime: Float) {
    elapsedTime += min(deltaTime, 0.1)
    let cameraPosition = arView.cameraTransform.translation

    for item in dustAnimations {
        var position = item.base
        position.x += sin(elapsedTime * 0.55 + item.phase) * 0.018
        position.y += sin(elapsedTime * 0.9 + item.phase * 1.7) * 0.025
        item.entity.position = position

        if let parent = item.entity.parent {
            let localCamera = parent.convert(position: cameraPosition, from: nil)
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
