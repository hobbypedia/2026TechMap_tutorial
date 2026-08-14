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
        let lensFlareView = SolarLensFlareView()
        lensFlareView.translatesAutoresizingMaskIntoConstraints = false
        arView.addSubview(lensFlareView)
        NSLayoutConstraint.activate([
            lensFlareView.leadingAnchor.constraint(equalTo: arView.leadingAnchor),
            lensFlareView.trailingAnchor.constraint(equalTo: arView.trailingAnchor),
            lensFlareView.topAnchor.constraint(equalTo: arView.topAnchor),
            lensFlareView.bottomAnchor.constraint(equalTo: arView.bottomAnchor)
        ])
        context.coordinator.connect(to: arView, lensFlareView: lensFlareView)

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
        private weak var lensFlareView: SolarLensFlareView?
        private let controller: ARExperienceController
        private let entityFactory = AirQualityEntityFactory()
        private var activeAnchor: AnchorEntity?
        private var visualizationRoot: Entity?
        private var sceneUpdateSubscription: (any Cancellable)?
        private var particleEmitters: [Entity] = []
        private var uvBeams: [Entity] = []
        private var sunCoronas: [Entity] = []
        private var sunlightGroup: Entity?
        private var sunEntity: Entity?
        private var sunlightSnapshot: AirQualitySnapshot?
        private var normalizedUV: Float = 0
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
        func connect(to arView: ARView, lensFlareView: SolarLensFlareView) {
            self.arView = arView
            self.lensFlareView = lensFlareView
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
            lensFlareView = nil
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
            collectAnimatedEntities(in: root, snapshot: snapshot)
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
            collectAnimatedEntities(in: visualizationRoot, snapshot: snapshot)
        }

        @MainActor
        private func collectAnimatedEntities(in root: Entity, snapshot: AirQualitySnapshot) {
            particleEmitters.removeAll(keepingCapacity: true)
            uvBeams.removeAll(keepingCapacity: true)
            sunCoronas.removeAll(keepingCapacity: true)
            sunlightGroup = nil
            sunEntity = nil
            sunlightSnapshot = snapshot
            normalizedUV = AirQualityVisualizationMapper.normalizedUV(for: snapshot.uvIndex)

            func visit(_ entity: Entity) {
                if entity.components.has(ParticleEmitterComponent.self) {
                    particleEmitters.append(entity)
                }
                if entity.name == "SunlightGroup" {
                    sunlightGroup = entity
                } else if entity.name.hasPrefix("SunBeam-") {
                    uvBeams.append(entity)
                } else if entity.name.hasPrefix("SunCorona") {
                    sunCoronas.append(entity)
                } else if entity.name == "SunSource" {
                    sunEntity = entity
                }
                entity.children.forEach(visit)
            }
            visit(root)
            appliedAnimationsEnabled = nil
            updateParticleSimulationIfNeeded()
        }

        @MainActor
        private func animate(deltaTime: Float) {
            guard let arView else { return }
            updateParticleSimulationIfNeeded()
            if animationsEnabled {
                elapsedTime += min(deltaTime, 0.1)
                let pulse = 1 + sin(elapsedTime * 1.35) * 0.035
                uvBeams.forEach { beam in
                    beam.scale = [pulse, pulse, pulse]
                }
            }

            let isSunVisible = sunlightSnapshot?.isSunVisible(at: Date()) ?? false
            sunlightGroup?.isEnabled = isSunVisible
            let cameraPosition = arView.cameraTransform.translation

            // 코로나 평면은 카메라를 바라보므로 태양이 납작한 카드나 구로 보이지 않습니다.
            sunCoronas.forEach { corona in
                guard let parent = corona.parent else { return }
                let localCameraPosition = parent.convert(position: cameraPosition, from: nil)
                let direction = localCameraPosition - corona.position
                if simd_length_squared(direction) > 0.0001 {
                    corona.orientation = simd_quatf(
                        from: [0, 0, 1],
                        to: simd_normalize(direction)
                    )
                }
                let pulse = animationsEnabled ? 1 + sin(elapsedTime * 1.05) * 0.03 : 1
                corona.scale = [pulse, pulse, pulse]
            }

            updateLensFlare(in: arView)
        }

        /// 월드 태양을 화면 좌표로 투영해 정면으로 올려다볼 때 렌즈 플레어를 표시합니다.
        @MainActor
        private func updateLensFlare(in arView: ARView) {
            guard let lensFlareView,
                  let sunEntity,
                  sunlightSnapshot?.isSunVisible(at: Date()) == true,
                  let frame = arView.session.currentFrame else {
                lensFlareView?.hide()
                return
            }

            let cameraTransform = frame.camera.transform
            let cameraPosition = SIMD3<Float>(
                cameraTransform.columns.3.x,
                cameraTransform.columns.3.y,
                cameraTransform.columns.3.z
            )
            let cameraForward = -SIMD3<Float>(
                cameraTransform.columns.2.x,
                cameraTransform.columns.2.y,
                cameraTransform.columns.2.z
            )
            let sunPosition = sunEntity.position(relativeTo: nil)
            let directionToSun = sunPosition - cameraPosition
            let alignment = AirQualityVisualizationMapper.solarFlareIntensity(
                cameraForward: cameraForward,
                directionToSun: directionToSun
            )
            let intensity = alignment * (0.66 + normalizedUV * 0.34)

            guard intensity > 0.001,
                  let screenPosition = arView.project(sunPosition),
                  arView.bounds.insetBy(dx: -40, dy: -40).contains(screenPosition) else {
                lensFlareView.hide()
                return
            }

            lensFlareView.update(
                sunPosition: screenPosition,
                intensity: intensity,
                phase: elapsedTime
            )
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
            uvBeams.removeAll(keepingCapacity: true)
            sunCoronas.removeAll(keepingCapacity: true)
            sunlightGroup = nil
            sunEntity = nil
            sunlightSnapshot = nil
            normalizedUV = 0
            lensFlareView?.hide()
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
