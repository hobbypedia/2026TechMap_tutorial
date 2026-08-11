sceneUpdateSubscription = arView.scene.subscribe(
    to: SceneEvents.Update.self
) { [weak self] event in
    self?.animate(deltaTime: Float(event.deltaTime))
}

private func collectAnimatedEntities(in root: Entity) {
    particleEmitters.removeAll(keepingCapacity: true)
    uvSpectrums.removeAll(keepingCapacity: true)

    func visit(_ entity: Entity) {
        if entity.components.has(ParticleEmitterComponent.self) {
            particleEmitters.append(entity)
        } else if entity.name.hasPrefix("UVSpectrum-") {
            uvSpectrums.append(entity)
        }
        entity.children.forEach(visit)
    }
    visit(root)
}

private func animate(deltaTime: Float) {
    elapsedTime += min(deltaTime, 0.1)
    let pulse = 1 + sin(elapsedTime * 1.35) * 0.035
    uvSpectrums.forEach { spectrum in
        spectrum.scale = [pulse, pulse, pulse]
    }
}
