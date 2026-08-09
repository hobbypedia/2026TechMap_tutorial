import RealityKit
import UIKit

/// 수치표 대신 공기 중 먼지와 자외선 에너지 오브젝트를 생성합니다.
final class AirQualityEntityFactory {
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
        if let pm25 = snapshot.pm25 {
            root.addChild(makeDustField(pm25: pm25))
        }
        root.addChild(makeUVObject(snapshot: snapshot))
    }

    private func makeDustField(pm25: Double) -> Entity {
        let group = Entity()
        group.name = "PM25DustField"
        group.position = [0, 0, 0]

        let texture = try? TextureResource.load(named: "DustParticle")
        let material = makeUnlitMaterial(
            texture: texture,
            tint: UIColor(red: 0.76, green: 0.58, blue: 0.25, alpha: 1),
            opacity: 0.40
        )
        let count = AirQualityVisualizationMapper.particleCount(forPM25: pm25)
        let sizePattern: [Float] = [0.042, 0.050, 0.058, 0.068, 0.078]

        for index in 0..<count {
            let baseSize = sizePattern[(index * 7) % sizePattern.count]
            let position = AirQualityVisualizationMapper.particlePosition(
                index: index,
                pm25: pm25
            )
            let size = baseSize
                * AirQualityVisualizationMapper.particleLinearScale
                * AirQualityVisualizationMapper.perspectiveScale(for: position)
            let particle = ModelEntity(
                mesh: .generatePlane(width: size, height: size),
                materials: [material]
            )
            particle.name = "DustParticle-\(index)"
            particle.position = position
            particle.orientation = simd_quatf(angle: Float(index % 9) * 0.17, axis: [0, 0, 1])
            group.addChild(particle)
        }

        return group
    }

    private func makeUVObject(snapshot: AirQualitySnapshot) -> Entity {
        let group = Entity()
        group.name = "UVGroup"
        group.position = [0, 0, 0]

        let normalized = AirQualityVisualizationMapper.normalizedUV(for: snapshot.uvIndex)
        let texture = try? TextureResource.load(named: "UVSpectrum")
        let opacity = AirQualityVisualizationMapper.uvOpacity(for: snapshot.uvIndex) * 0.35
        let material = makeUnlitMaterial(texture: texture, tint: .white, opacity: opacity)
        let size = 1.65 + normalized * 0.35
        let beamCount = 8
        let sourceHeight: Float = 1.45
        let radialOffset: Float = 0.6
        let halfHeight = size * 0.5
        let tilt = asin(min(radialOffset / halfHeight, 0.95))
        let centerHeight = sourceHeight - cos(tilt) * halfHeight

        for index in 0..<beamCount {
            let yaw = Float(index) * 2 * .pi / Float(beamCount)
            let yawRotation = simd_quatf(angle: yaw, axis: [0, 1, 0])
            let tiltRotation = simd_quatf(angle: tilt, axis: [1, 0, 0])
            let spectrum = ModelEntity(
                mesh: .generatePlane(width: size, height: size),
                materials: [material]
            )
            spectrum.name = "UVSpectrum-" + String(index)
            spectrum.position = yawRotation.act([0, centerHeight, -radialOffset])
            spectrum.orientation = yawRotation * tiltRotation
            group.addChild(spectrum)
        }

        return group
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
