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

/// ARKit 세션을 시작하고 RealityKit 콘텐츠를 사용자 주변의 중력 정렬 월드 공간에 배치합니다.
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
        configuration.worldAlignment = .gravity
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
        private var dustAnimations: [(entity: Entity, base: SIMD3<Float>, phase: Float)] = []
        private var uvSpectrums: [Entity] = []
        private var elapsedTime: Float = 0
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

        private func makeEnvironmentTransform(from cameraTransform: simd_float4x4) -> simd_float4x4 {
            var forward = -SIMD3<Float>(
                cameraTransform.columns.2.x,
                0,
                cameraTransform.columns.2.z
            )
            if simd_length_squared(forward) < 0.0001 {
                forward = [0, 0, -1]
            } else {
                forward = simd_normalize(forward)
            }

            let up = SIMD3<Float>(0, 1, 0)
            let right = simd_normalize(simd_cross(forward, up))
            var transform = matrix_identity_float4x4
            transform.columns.0 = SIMD4<Float>(right.x, right.y, right.z, 0)
            transform.columns.1 = SIMD4<Float>(up.x, up.y, up.z, 0)
            transform.columns.2 = SIMD4<Float>(-forward.x, -forward.y, -forward.z, 0)
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
            dustAnimations.removeAll(keepingCapacity: true)
            uvSpectrums.removeAll(keepingCapacity: true)

            func visit(_ entity: Entity) {
                if entity.name.hasPrefix("DustParticle-") {
                    let phase = Float(dustAnimations.count) * 0.73
                    dustAnimations.append((entity, entity.position, phase))
                } else if entity.name.hasPrefix("UVSpectrum-") {
                    uvSpectrums.append(entity)
                }
                entity.children.forEach(visit)
            }
            visit(root)
        }

        @MainActor
        private func animate(deltaTime: Float) {
            guard let arView else { return }
            if animationsEnabled {
                elapsedTime += min(deltaTime, 0.1)
            }

            let cameraPosition = arView.cameraTransform.translation
            for item in dustAnimations {
                var position = item.base
                if animationsEnabled {
                    position.x += sin(elapsedTime * 0.55 + item.phase) * 0.018
                    position.y += sin(elapsedTime * 0.9 + item.phase * 1.7) * 0.025
                    position.z += cos(elapsedTime * 0.4 + item.phase) * 0.008
                }
                item.entity.position = position
                if let parent = item.entity.parent {
                    let localCameraPosition = parent.convert(position: cameraPosition, from: nil)
                    let direction = localCameraPosition - position
                    if simd_length_squared(direction) > 0.0001 {
                        item.entity.orientation = simd_quatf(
                            from: [0, 0, 1],
                            to: simd_normalize(direction)
                        )
                    }
                }
            }

            if animationsEnabled {
                let pulse = 1 + sin(elapsedTime * 1.35) * 0.035
                uvSpectrums.forEach { spectrum in
                    spectrum.scale = [pulse, pulse, pulse]
                }
            }
        }

        /// 월드 공간에 배치된 환경 데이터 시각화를 제거합니다.
        @MainActor
        func removeAllVisualizations() {
            activeAnchor?.removeFromParent()
            activeAnchor = nil
            visualizationRoot = nil
            dustAnimations.removeAll()
            uvSpectrums.removeAll(keepingCapacity: true)
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
            configuration.worldAlignment = .gravity
            session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        }

        func session(_ session: ARSession, didFailWithError error: Error) {
            DispatchQueue.main.async { [weak self] in self?.stateDidChange(.unavailable) }
        }
    }
}
