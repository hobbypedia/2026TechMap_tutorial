sceneUpdateSubscription = arView.scene.subscribe(
    to: SceneEvents.Update.self
) { [weak self] event in
    self?.animate(deltaTime: Float(event.deltaTime))
}

private func animate(deltaTime: Float) {
    let isDaytime = snapshot.isSunVisible(at: Date())
    sunlightGroup.isEnabled = isDaytime

    particleEmitters.forEach { entity in
        guard var emitter = entity.components[ParticleEmitterComponent.self] else { return }
        emitter.simulationState = animationsEnabled ? .play : .pause
        entity.components.set(emitter)
    }

    guard isDaytime else {
        lensFlareView.hide()
        return
    }

    // 코로나는 카메라를 향하고, 월드 태양을 화면 좌표로 투영합니다.
    faceCamera(sunCorona, from: arView.cameraTransform.translation)
    let screenPosition = arView.project(sunSource.position(relativeTo: nil))
    lensFlareView.update(
        sunPosition: screenPosition,
        intensity: flareIntensity,
        phase: elapsedTime
    )
}
