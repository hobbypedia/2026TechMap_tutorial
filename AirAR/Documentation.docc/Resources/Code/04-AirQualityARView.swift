import ARKit
import Combine
import RealityKit
import SwiftUI

@MainActor
final class ARExperienceController: ObservableObject {
    @Published private(set) var isPlaced = false

    fileprivate var placeHandler: ((AirQualitySnapshot) -> Void)?
    fileprivate var updateHandler: ((AirQualitySnapshot) -> Void)?

    func place(_ snapshot: AirQualitySnapshot) {
        placeHandler?(snapshot)
    }

    func update(_ snapshot: AirQualitySnapshot) {
        updateHandler?(snapshot)
    }

    fileprivate func setPlaced(_ value: Bool) {
        isPlaced = value
    }
}

/// 4단계 체크포인트: 추적이 준비되면 PM2.5 파티클을 월드 공간에 배치합니다.
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
            DispatchQueue.main.async { sessionState = .unsupported }
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
        context.coordinator.stateDidChange = { state in sessionState = state }
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
        private var particleEmitters: [Entity] = []
        private var sceneUpdateSubscription: (any Cancellable)?
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
            sceneUpdateSubscription = arView.scene.subscribe(
                to: SceneEvents.Update.self
            ) { [weak self] _ in
                self?.updateParticleSimulationIfNeeded()
            }
        }

        @MainActor
        func disconnect() {
            controller.placeHandler = nil
            controller.updateHandler = nil
            sceneUpdateSubscription?.cancel()
            sceneUpdateSubscription = nil
            activeAnchor?.removeFromParent()
            activeAnchor = nil
            visualizationRoot = nil
            particleEmitters.removeAll()
            controller.setPlaced(false)
            arView = nil
        }

        @MainActor
        private func place(_ snapshot: AirQualitySnapshot) {
            guard let arView,
                  let cameraTransform = arView.session.currentFrame?.camera.transform else {
                return
            }

            activeAnchor?.removeFromParent()
            var worldTransform = matrix_identity_float4x4
            worldTransform.columns.3 = cameraTransform.columns.3
            let anchor = AnchorEntity(world: worldTransform)
            let root = entityFactory.makeVisualization(from: snapshot)
            anchor.addChild(root)
            arView.scene.addAnchor(anchor)
            activeAnchor = anchor
            visualizationRoot = root
            collectParticleEmitters(in: root)
            controller.setPlaced(true)
        }

        @MainActor
        private func update(_ snapshot: AirQualitySnapshot) {
            guard let visualizationRoot else { return }
            entityFactory.updateVisualization(root: visualizationRoot, with: snapshot)
            collectParticleEmitters(in: visualizationRoot)
        }

        @MainActor
        private func collectParticleEmitters(in root: Entity) {
            particleEmitters.removeAll(keepingCapacity: true)
            func visit(_ entity: Entity) {
                if entity.components.has(ParticleEmitterComponent.self) {
                    particleEmitters.append(entity)
                }
                entity.children.forEach(visit)
            }
            visit(root)
            appliedAnimationsEnabled = nil
            updateParticleSimulationIfNeeded()
        }

        @MainActor
        private func updateParticleSimulationIfNeeded() {
            guard appliedAnimationsEnabled != animationsEnabled else { return }
            for entity in particleEmitters {
                guard var component = entity.components[
                    ParticleEmitterComponent.self
                ] else { continue }
                component.simulationState = animationsEnabled ? .play : .pause
                entity.components.set(component)
            }
            appliedAnimationsEnabled = animationsEnabled
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
