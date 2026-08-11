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
        root.addChild(makeDustEmitter(from: snapshot))
        root.addChild(makeUVObject(snapshot: snapshot))
    }

    /// iOS 18의 RealityKit 파티클 시스템으로 이미지 에셋 없이 미세먼지를 만듭니다.
    private func makeDustEmitter(from snapshot: AirQualitySnapshot) -> Entity {
        let entity = Entity()
        entity.name = "PM25DustEmitter"

        let travelDirection = AirQualityVisualizationMapper.windTravelDirection(
            forMeteorologicalDegrees: snapshot.windDirection
        )
        let visualWindSpeed = AirQualityVisualizationMapper.visualWindSpeed(
            forMetersPerSecond: snapshot.windSpeed
        )
        let opacity = AirQualityVisualizationMapper.dustOpacity(forPM25: snapshot.pm25)

        var component = ParticleEmitterComponent()
        component.emitterShape = .box
        component.birthLocation = .volume
        component.birthDirection = .local
        component.emitterShapeSize = [5.8, 1.8, 5.8]
        component.emissionDirection = [travelDirection.x, 0.04, travelDirection.y]
        component.speed = max(visualWindSpeed, 0.025)
        component.speedVariation = max(component.speed * 0.45, 0.015)
        component.particlesInheritTransform = false
        component.fieldSimulationSpace = .local
        component.timing = .repeating(warmUp: 2.5, emit: .init(duration: 1))

        var particles = component.mainEmitter
        particles.birthRate = AirQualityVisualizationMapper.dustBirthRate(forPM25: snapshot.pm25)
        particles.birthRateVariation = particles.birthRate * 0.12
        particles.lifeSpan = 5.5
        particles.lifeSpanVariation = 1.3
        particles.size = 0.020
        particles.sizeVariation = 0.012
        particles.billboardMode = .billboard
        particles.opacityCurve = .gradualFadeInOut
        particles.sizeMultiplierAtEndOfLifespan = 0.72
        particles.dampingFactor = 0.035
        particles.spreadingAngle = 0.10
        particles.noiseStrength = 0.11
        particles.noiseScale = 0.72
        particles.noiseAnimationSpeed = 0.16
        particles.angleVariation = .pi
        particles.angularSpeedVariation = 0.35
        particles.isLightingEnabled = false
        particles.sortOrder = .increasingDepth
        particles.blendMode = .alpha
        particles.color = .evolving(
            start: .random(
                a: UIColor(red: 0.52, green: 0.42, blue: 0.24, alpha: CGFloat(opacity * 0.70)),
                b: UIColor(red: 0.82, green: 0.69, blue: 0.42, alpha: CGFloat(opacity))
            ),
            end: .single(UIColor(red: 0.63, green: 0.52, blue: 0.31, alpha: 0))
        )
        component.mainEmitter = particles
        entity.components.set(component)
        return entity
    }

    private func makeUVObject(snapshot: AirQualitySnapshot) -> Entity {
        let group = Entity()
        group.name = "SunlightGroup"
        group.position = [0, 0, 0]
        group.isEnabled = snapshot.isSunVisible()

        let normalized = AirQualityVisualizationMapper.normalizedUV(for: snapshot.uvIndex)
        let opacity = AirQualityVisualizationMapper.uvOpacity(for: snapshot.uvIndex) * 0.28
        let material = makeUVMaterial(normalizedUV: normalized, opacity: opacity)
        let size = 2.3 + normalized * 0.4
        let beamCount = 2
        let sourceHeight: Float = 2.4
        let radialOffset: Float = 0.45
        let halfHeight = size * 0.5
        let tilt = asin(min(radialOffset / halfHeight, 0.95))
        let centerHeight = sourceHeight - cos(tilt) * halfHeight

        for index in 0..<beamCount {
            // 양면 평면 두 장을 직각으로 교차해 어느 방향에서도 보이되 색 중첩은 줄입니다.
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
            let coronaSize = 0.58 + normalized * 0.20
            let corona = ModelEntity(
                mesh: .generatePlane(width: coronaSize, height: coronaSize),
                materials: [coronaMaterial]
            )
            corona.name = "SunCorona"
            corona.position = [0, sourceHeight, 0]
            group.addChild(corona)
        }

        let sourceMaterial = makeUnlitMaterial(
            texture: nil,
            tint: UIColor(red: 1, green: 0.985, blue: 0.88, alpha: 1),
            opacity: 0.90 + normalized * 0.10
        )
        let source = ModelEntity(
            mesh: .generateSphere(radius: 0.10 + normalized * 0.04),
            materials: [sourceMaterial]
        )
        source.name = "SunSource"
        source.position = [0, sourceHeight, 0]
        group.addChild(source)

        return group
    }

    /// Metal surface shader가 UV 좌표에서 따뜻한 햇빛과 페이드를 계산합니다.
    /// 셰이더를 불러오지 못해도 이미지 없이 단색 빔으로 계속 표시합니다.
    private func makeUVMaterial(normalizedUV: Float, opacity: Float) -> any Material {
        guard let uvSurfaceShader,
              var material = try? CustomMaterial(
                surfaceShader: uvSurfaceShader,
                lightingModel: .unlit
              ) else {
            return makeUnlitMaterial(
                texture: nil,
                tint: UIColor(red: 1, green: 0.90, blue: 0.66, alpha: 1),
                opacity: opacity
            )
        }

        material.custom.value = [normalizedUV, opacity, 0, 0]
        material.blending = .transparent(opacity: .init(floatLiteral: 1.0))
        material.faceCulling = .none
        return material
    }

    /// 카메라를 향하는 평면에 중심광, 코로나와 불규칙한 광선을 절차적으로 그립니다.
    private func makeSunCoronaMaterial(normalizedUV: Float) -> (any Material)? {
        guard let sunCoronaSurfaceShader,
              var material = try? CustomMaterial(
                surfaceShader: sunCoronaSurfaceShader,
                lightingModel: .unlit
              ) else {
            return nil
        }

        material.custom.value = [normalizedUV, 0.72 + normalizedUV * 0.22, 0, 0]
        material.blending = .transparent(opacity: .init(floatLiteral: 1.0))
        material.faceCulling = .none
        return material
    }

    private func makeUnlitMaterial(
        texture: TextureResource?,
        tint: UIColor,
        opacity: Float
    ) -> UnlitMaterial {
        var material = UnlitMaterial()
        if let texture {
            material.color = .init(tint: tint, texture: .init(texture))
        } else {
            material.color = .init(tint: tint)
        }
        material.blending = .transparent(opacity: .init(floatLiteral: opacity))
        return material
    }

}
