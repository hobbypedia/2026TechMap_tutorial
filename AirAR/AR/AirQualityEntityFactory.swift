import Metal
import RealityKit
import UIKit

/// 수치표 대신 공기 중 먼지와 자외선 에너지 오브젝트를 생성합니다.
final class AirQualityEntityFactory {
    private lazy var uvSurfaceShader: CustomMaterial.SurfaceShader? = {
        guard let device = MTLCreateSystemDefaultDevice(),
              let library = device.makeDefaultLibrary() else {
            return nil
        }
        return CustomMaterial.SurfaceShader(named: "uvBeamSurface", in: library)
    }()

    private lazy var sunCoronaSurfaceShader: CustomMaterial.SurfaceShader? = {
        guard let device = MTLCreateSystemDefaultDevice(),
              let library = device.makeDefaultLibrary() else {
            return nil
        }
        return CustomMaterial.SurfaceShader(named: "sunCoronaSurface", in: library)
    }()

    /// 환경 데이터 전체 시각화를 만듭니다.
    func makeVisualization(from snapshot: AirQualitySnapshot) -> Entity {
        let root = Entity()
        root.name = "AirQualityRootEntity"
        rebuild(root: root, snapshot: snapshot)
        return root
    }

    /// 기존 루트 엔티티를 새 데이터로 갱신합니다.
    func updateVisualization(root: Entity, with snapshot: AirQualitySnapshot) {
        root.children.forEach { $0.removeFromParent() }
        rebuild(root: root, snapshot: snapshot)
    }

    private func rebuild(root: Entity, snapshot: AirQualitySnapshot) {
        root.addChild(makeDustField(snapshot: snapshot))
        root.addChild(makeUVObject(snapshot: snapshot))
    }

    private func makeDustField(snapshot: AirQualitySnapshot) -> Entity {
        let emitterEntity = Entity()
        emitterEntity.name = "PM25ParticleEmitter"

        let radius = AirQualityVisualizationMapper.dustFieldRadius(forPM25: snapshot.pm25)
        let speed = AirQualityVisualizationMapper.visualWindSpeed(
            forMetersPerSecond: snapshot.windSpeed
        )
        var component = ParticleEmitterComponent()
        component.emitterShape = .sphere
        component.emitterShapeSize = [radius * 2, 1.6, radius * 2]
        component.birthLocation = .volume
        component.birthDirection = .world
        component.emissionDirection = AirQualityVisualizationMapper.emitterDirection(
            forMeteorologicalDegrees: snapshot.windDirection
        )
        component.speed = speed
        component.speedVariation = max(speed * 0.35, 0.02)
        component.timing = .repeating(
            emit: .init(duration: 1),
            idle: nil
        )

        component.mainEmitter.birthRate = AirQualityVisualizationMapper.particleBirthRate(
            forPM25: snapshot.pm25
        )
        component.mainEmitter.birthRateVariation = component.mainEmitter.birthRate * 0.12
        component.mainEmitter.lifeSpan = AirQualityVisualizationMapper.particleLifeSpan
        component.mainEmitter.lifeSpanVariation = 1.2
        component.mainEmitter.size = 0.05
        component.mainEmitter.sizeVariation = 0.012
        component.mainEmitter.billboardMode = .billboard
        component.mainEmitter.opacityCurve = .gradualFadeInOut
        component.mainEmitter.noiseStrength = 0.08
        component.mainEmitter.noiseScale = 0.65
        component.mainEmitter.noiseAnimationSpeed = 0.18
        component.mainEmitter.color = .constant(
            .single(UIColor(red: 0.76, green: 0.58, blue: 0.25, alpha: 0.42))
        )
        // image를 지정하지 않아 RealityKit의 기본 원형 파티클 텍스처를 사용합니다.
        emitterEntity.components.set(component)
        return emitterEntity
    }

    private func makeUVObject(snapshot: AirQualitySnapshot) -> Entity {
        let group = Entity()
        group.name = "SunlightGroup"
        group.position = [0, 0, 0]
        group.isEnabled = snapshot.isSunVisible()

        let normalized = AirQualityVisualizationMapper.normalizedUV(for: snapshot.uvIndex)
        let opacity = AirQualityVisualizationMapper.uvOpacity(for: snapshot.uvIndex) * 0.26
        let material = makeUVMaterial(normalizedUV: normalized, opacity: opacity)
        let size = 2.45 + normalized * 0.45
        let beamCount = 2
        let sourceHeight: Float = 2.4
        let radialOffset: Float = 0.48
        let halfHeight = size * 0.5
        let tilt = asin(min(radialOffset / halfHeight, 0.95))
        let centerHeight = sourceHeight - cos(tilt) * halfHeight

        for index in 0..<beamCount {
            // 양면 평면 두 장을 직각으로 교차해 모든 방향에서 보이면서 흰색 중첩은 줄입니다.
            let yaw = Float(index) * .pi / Float(beamCount)
            let yawRotation = simd_quatf(angle: yaw, axis: [0, 1, 0])
            let tiltRotation = simd_quatf(angle: tilt, axis: [1, 0, 0])
            let beam = ModelEntity(
                mesh: .generatePlane(width: size, height: size),
                materials: [material]
            )
            beam.name = "SunBeam-" + String(index)
            beam.position = yawRotation.act([0, centerHeight, -radialOffset])
            beam.orientation = yawRotation * tiltRotation
            group.addChild(beam)
        }

        if let coronaMaterial = makeSunCoronaMaterial(normalizedUV: normalized) {
            let coronaSize = 0.82 + normalized * 0.24
            let corona = ModelEntity(
                mesh: .generatePlane(width: coronaSize, height: coronaSize),
                materials: [coronaMaterial]
            )
            corona.name = "SunCorona"
            corona.position = [0, sourceHeight, 0]
            group.addChild(corona)
        }

        // 실제 원형 메시를 드러내지 않고 화면 투영과 렌즈 플레어 기준점으로만 사용합니다.
        let source = Entity()
        source.name = "SunSource"
        source.position = [0, sourceHeight, 0]
        group.addChild(source)

        return group
    }

    /// Metal surface shader가 UV 좌표만으로 따뜻한 햇빛과 부드러운 가장자리를 만듭니다.
    private func makeUVMaterial(normalizedUV: Float, opacity: Float) -> any Material {
        guard let uvSurfaceShader,
              var material = try? CustomMaterial(
                surfaceShader: uvSurfaceShader,
                lightingModel: .unlit
              ) else {
            var fallback = UnlitMaterial()
            fallback.color = .init(
                tint: UIColor(red: 1, green: 0.88, blue: 0.58, alpha: 1)
            )
            fallback.blending = .transparent(opacity: .init(floatLiteral: opacity))
            return fallback
        }

        material.custom.value = [normalizedUV, opacity, 0, 0]
        material.blending = .transparent(opacity: .init(floatLiteral: 1))
        material.faceCulling = .none
        return material
    }

    /// 태양 원반, 금빛 헤일로와 뾰족한 코로나 광선을 하나의 빌보드 평면에 그립니다.
    private func makeSunCoronaMaterial(normalizedUV: Float) -> (any Material)? {
        guard let sunCoronaSurfaceShader,
              var material = try? CustomMaterial(
                surfaceShader: sunCoronaSurfaceShader,
                lightingModel: .unlit
              ) else {
            return nil
        }

        material.custom.value = [normalizedUV, 0.88 + normalizedUV * 0.12, 0, 0]
        material.blending = .transparent(opacity: .init(floatLiteral: 1))
        material.faceCulling = .none
        return material
    }
}
