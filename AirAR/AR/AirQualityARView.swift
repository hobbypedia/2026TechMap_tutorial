import ARKit
import Combine
import RealityKit
import SwiftUI

/// SwiftUI 버튼의 명령을 현재 ARView에 전달하는 컨트롤러입니다.
@MainActor
final class ARExperienceController: ObservableObject {
    @Published private(set) var isPlaced = false

    fileprivate var placeHandler: ((AirQualitySnapshot) -> Void)?
    fileprivate var updateHandler: ((AirQualitySnapshot) -> Void)?
    fileprivate var resetHandler: (() -> Void)?

    func place(_ snapshot: AirQualitySnapshot) {
        placeHandler?(snapshot)
    }

    func update(_ snapshot: AirQualitySnapshot) {
        updateHandler?(snapshot)
    }

    func reset() {
        resetHandler?()
    }

    fileprivate func setPlaced(_ value: Bool) {
        isPlaced = value
    }
}

/// ARKit 세션을 시작하고 RealityKit 콘텐츠를 사용자 주변의 중력·북쪽 정렬 월드 공간에 배치합니다.
struct AirQualityARView: UIViewRepresentable {
    @ObservedObject var controller: ARExperienceController
    @Binding var sessionState: ARSessionState
    let animationsEnabled: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller, animationsEnabled: animationsEnabled) { state in
            sessionState = state
        }
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        context.coordinator.connect(to: arView)

        guard ARWorldTrackingConfiguration.isSupported else {
            DispatchQueue.main.async {
                sessionState = .unsupported
            }
            return arView
        }

        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.session = arView.session
        coachingOverlay.goal = .tracking
        coachingOverlay.activatesAutomatically = true
        coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
        arView.addSubview(coachingOverlay)
        NSLayoutConstraint.activate([
            coachingOverlay.leadingAnchor.constraint(equalTo: arView.leadingAnchor),
            coachingOverlay.trailingAnchor.constraint(equalTo: arView.trailingAnchor),
            coachingOverlay.topAnchor.constraint(equalTo: arView.topAnchor),
            coachingOverlay.bottomAnchor.constraint(equalTo: arView.bottomAnchor)
        ])

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.animationsEnabled = animationsEnabled
        context.coordinator.stateDidChange = { state in
            sessionState = state
        }
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.disconnect()
        uiView.session.pause()
    }

    final class Coordinator: NSObject, ARSessionDelegate {
        private weak var arView: ARView?
        private let controller: ARExperienceController
        private let entityFactory = AirQualityEntityFactory()
        private var activeAnchor: AnchorEntity?
        private var visualizationRoot: Entity?
        private var sceneUpdateSubscription: (any Cancellable)?
        private var particleEmitters: [Entity] = []
        private var uvSpectrums: [Entity] = []
        private var elapsedTime: Float = 0
        private var appliedAnimationsEnabled: Bool?
        var animationsEnabled: Bool
        var stateDidChange: (ARSessionState) -> Void

        init(
            controller: ARExperienceController,
            animationsEnabled: Bool,
            stateDidChange: @escaping (ARSessionState) -> Void
        ) {
            self.controller = controller
            self.animationsEnabled = animationsEnabled
            self.stateDidChange = stateDidChange
        }

        @MainActor
        func connect(to arView: ARView) {
            self.arView = arView
            arView.session.delegate = self
            controller.placeHandler = { [weak self] snapshot in self?.place(snapshot) }
            controller.updateHandler = { [weak self] snapshot in self?.update(snapshot) }
            controller.resetHandler = { [weak self] in self?.removeAllVisualizations() }
            sceneUpdateSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
                self?.animate(deltaTime: Float(event.deltaTime))
            }
        }

        @MainActor
        func disconnect() {
            controller.placeHandler = nil
            controller.updateHandler = nil
            controller.resetHandler = nil
            sceneUpdateSubscription?.cancel()
            sceneUpdateSubscription = nil
            removeAllVisualizations()
        }

        @MainActor
        private func place(_ snapshot: AirQualitySnapshot) {
            guard let arView,
                  let cameraTransform = arView.session.currentFrame?.camera.transform else {
                return
            }

            removeAllVisualizations()
            let anchor = AnchorEntity(world: makeEnvironmentTransform(from: cameraTransform))
            let root = entityFactory.makeVisualization(from: snapshot)
            anchor.addChild(root)
            arView.scene.addAnchor(anchor)
            activeAnchor = anchor
            visualizationRoot = root
            collectAnimatedEntities(in: root)
            controller.setPlaced(true)
        }

        /// 앵커 축을 월드의 동·서·남·북과 일치시키고 위치만 현재 카메라로 옮깁니다.
        private func makeEnvironmentTransform(from cameraTransform: simd_float4x4) -> simd_float4x4 {
            var transform = matrix_identity_float4x4
            transform.columns.3 = cameraTransform.columns.3
            return transform
        }

        @MainActor
        private func update(_ snapshot: AirQualitySnapshot) {
            guard let visualizationRoot else { return }
            entityFactory.updateVisualization(root: visualizationRoot, with: snapshot)
            collectAnimatedEntities(in: visualizationRoot)
        }

        @MainActor
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
            appliedAnimationsEnabled = nil
            updateParticleSimulationIfNeeded()
        }

        @MainActor
        private func animate(deltaTime: Float) {
            updateParticleSimulationIfNeeded()
            if animationsEnabled {
                elapsedTime += min(deltaTime, 0.1)
                let pulse = 1 + sin(elapsedTime * 1.35) * 0.035
                uvSpectrums.forEach { spectrum in
                    spectrum.scale = [pulse, pulse, pulse]
                }
            }
        }

        @MainActor
        private func updateParticleSimulationIfNeeded() {
            guard appliedAnimationsEnabled != animationsEnabled else { return }
            for entity in particleEmitters {
                guard var component = entity.components[ParticleEmitterComponent.self] else { continue }
                component.simulationState = animationsEnabled ? .play : .pause
                entity.components.set(component)
            }
            appliedAnimationsEnabled = animationsEnabled
        }

        /// 월드 공간에 배치된 환경 데이터 시각화를 제거합니다.
        @MainActor
        func removeAllVisualizations() {
            activeAnchor?.removeFromParent()
            activeAnchor = nil
            visualizationRoot = nil
            particleEmitters.removeAll()
            uvSpectrums.removeAll(keepingCapacity: true)
            appliedAnimationsEnabled = nil
            elapsedTime = 0
            controller.setPlaced(false)
        }

        func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            let state = ARSessionState.map(camera.trackingState)
            DispatchQueue.main.async { [weak self] in self?.stateDidChange(state) }
        }

        func sessionWasInterrupted(_ session: ARSession) {
            DispatchQueue.main.async { [weak self] in self?.stateDidChange(.interrupted) }
        }

        func sessionInterruptionEnded(_ session: ARSession) {
            DispatchQueue.main.async { [weak self] in self?.stateDidChange(.resumed) }
            guard ARWorldTrackingConfiguration.isSupported else { return }
            let configuration = ARWorldTrackingConfiguration()
            configuration.worldAlignment = .gravityAndHeading
            session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        }

        func session(_ session: ARSession, didFailWithError error: Error) {
            DispatchQueue.main.async { [weak self] in self?.stateDidChange(.unavailable) }
        }
    }
}
