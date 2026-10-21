import ARKit
import Combine
import RealityKit
import SwiftUI

/// Forwards commands from SwiftUI buttons to the current ARView.
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

/// Starts an ARKit session and places RealityKit content around the user in a gravity- and north-aligned world.
/// ARKit 세션을 시작하고 RealityKit 콘텐츠를 사용자 주변의 중력·북쪽 정렬 월드 공간에 배치합니다.
struct AirQualityARView: UIViewRepresentable {
    @ObservedObject var controller: ARExperienceController
    @Binding var sessionState: ARSessionState
    let animationsEnabled: Bool

    /// Keeps AR session callbacks and scene state in a coordinator across SwiftUI view updates.
    /// SwiftUI 뷰 갱신 사이에도 AR 세션 콜백과 장면 상태를 코디네이터에서 유지합니다.
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
        // Align the world with gravity and compass heading so wind directions use a consistent frame.
        // 풍향에 일관된 기준을 사용하도록 월드를 중력과 나침반 방위에 맞춥니다.
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

    /// Releases scene subscriptions and pauses tracking when SwiftUI removes the view.
    /// SwiftUI가 뷰를 제거하면 장면 구독을 해제하고 추적을 일시 정지합니다.
    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        coordinator.disconnect()
        uiView.session.pause()
    }

    /// Owns the bridge between SwiftUI commands, AR session events, and RealityKit entities.
    /// SwiftUI 명령, AR 세션 이벤트, RealityKit 엔티티 사이의 연결을 관리합니다.
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
            // Capture the coordinator weakly so stored callbacks do not keep it alive after dismissal.
            // 저장된 콜백이 화면 종료 후에도 코디네이터를 유지하지 않도록 약하게 참조합니다.
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

        /// Keeps the anchor aligned with world cardinal directions and moves only its position to the current camera.
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

            // Traverse once after rebuilding to cache the entities needed by per-frame animation.
            // 장면을 다시 만든 뒤 한 번 순회하여 프레임별 애니메이션에 필요한 엔티티를 저장합니다.
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
                // Cap the time step to prevent a long frame from causing a large animation jump.
                // 프레임 처리가 오래 걸려도 애니메이션이 크게 뛰지 않도록 시간 증가량을 제한합니다.
                elapsedTime += min(deltaTime, 0.1)
                let pulse = 1 + sin(elapsedTime * 1.35) * 0.035
                uvBeams.forEach { beam in
                    beam.scale = [pulse, pulse, pulse]
                }
            }

            let isSunVisible = sunlightSnapshot?.isSunVisible(at: Date()) ?? false
            sunlightGroup?.isEnabled = isSunVisible
            let cameraPosition = arView.cameraTransform.translation

            // Faces the corona plane toward the camera to preserve its sun-like appearance.
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

        /// Projects the world-space sun onto the screen and shows lens flare when looking toward it.
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
            // The camera looks along its negative local Z axis; read that axis from the world transform.
            // 카메라는 로컬 Z축의 음수 방향을 바라보므로 월드 변환 행렬에서 해당 축을 읽습니다.
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
            // Update particle components only when the requested play/pause state changes.
            // 요청된 재생·일시 정지 상태가 바뀔 때만 파티클 컴포넌트를 갱신합니다.
            guard appliedAnimationsEnabled != animationsEnabled else { return }
            for entity in particleEmitters {
                guard var component = entity.components[ParticleEmitterComponent.self] else { continue }
                component.simulationState = animationsEnabled ? .play : .pause
                entity.components.set(component)
            }
            appliedAnimationsEnabled = animationsEnabled
        }

        /// Removes the environmental visualization placed in world space.
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
            // Translate tracking events into screen state and deliver the change on the main queue.
            // 추적 이벤트를 화면 상태로 변환하고 메인 큐에서 변경 사항을 전달합니다.
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
