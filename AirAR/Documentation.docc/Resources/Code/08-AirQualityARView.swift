sceneUpdateSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
    self?.animate(deltaTime: Float(event.deltaTime))
}

@MainActor
private func animate(deltaTime: Float) {
    guard let arView else { return }
    if animationsEnabled {
        elapsedTime += min(deltaTime, 0.1)
    }

    // 먼지는 ParticleEmitterComponent가 생성, 이동, 소멸까지 스스로 갱신합니다.
    let isSunVisible = sunlightSnapshot?.isSunVisible(at: Date()) ?? false
    sunlightGroup?.isEnabled = isSunVisible

    if animationsEnabled {
        let pulse = 1 + sin(elapsedTime * 1.35) * 0.035
        uvBeams.forEach { beam in
            beam.scale = [pulse, pulse, pulse]
        }
    }

    updateSunCoronaFacingCamera(in: arView)
    updateLensFlare(in: arView)
}
