import Metal
import RealityKit

let normalized = min(max(Float(uvIndex / 11), 0), 1)
let opacity = (0.06 + normalized * 0.36) * 0.28

let device = MTLCreateSystemDefaultDevice()
let library = device?.makeDefaultLibrary()
let beamShader = library.map {
    CustomMaterial.SurfaceShader(named: "uvBeamSurface", in: $0)
}
let coronaShader = library.map {
    CustomMaterial.SurfaceShader(named: "sunCoronaSurface", in: $0)
}

guard let beamShader,
      var material = try? CustomMaterial(
        surfaceShader: beamShader,
        lightingModel: .unlit
      ) else {
    return
}

material.custom.value = [normalized, opacity, 0, 0]
material.blending = .transparent(opacity: .init(floatLiteral: 1.0))
material.faceCulling = .none

let sunlightGroup = Entity()
sunlightGroup.isEnabled = snapshot.isSunVisible()
let size = 2.3 + normalized * 0.4
let sourceHeight: Float = 2.4
let radialOffset: Float = 0.45
let halfHeight = size * 0.5
let tilt = asin(min(radialOffset / halfHeight, 0.95))
let centerHeight = sourceHeight - cos(tilt) * halfHeight

// 같은 평면이 180°에서 반복되므로 0°와 90° 두 장만 교차합니다.
for index in 0..<2 {
    let yaw = Float(index) * .pi / 2
    let yawRotation = simd_quatf(angle: yaw, axis: [0, 1, 0])
    let tiltRotation = simd_quatf(angle: tilt, axis: [1, 0, 0])
    let beam = ModelEntity(
        mesh: .generatePlane(width: size, height: size),
        materials: [material]
    )
    beam.name = "SunBeam-" + String(index)
    beam.position = yawRotation.act([0, centerHeight, -radialOffset])
    beam.orientation = yawRotation * tiltRotation
    sunlightGroup.addChild(beam)
}

// 같은 Metal 파일의 두 번째 함수가 중심광, 후광과 불규칙한 광선을 그립니다.
if let coronaShader,
   var coronaMaterial = try? CustomMaterial(
    surfaceShader: coronaShader,
    lightingModel: .unlit
   ) {
    coronaMaterial.custom.value = [normalized, 0.72 + normalized * 0.22, 0, 0]
    coronaMaterial.blending = .transparent(opacity: .init(floatLiteral: 1.0))
    coronaMaterial.faceCulling = .none

    let coronaSize = 0.58 + normalized * 0.20
    let corona = ModelEntity(
        mesh: .generatePlane(width: coronaSize, height: coronaSize),
        materials: [coronaMaterial]
    )
    corona.name = "SunCorona"
    corona.position = [0, sourceHeight, 0]
    sunlightGroup.addChild(corona)
}

var sunMaterial = UnlitMaterial(color: .white)
sunMaterial.blending = .transparent(
    opacity: .init(floatLiteral: 0.72 + normalized * 0.24)
)
let sun = ModelEntity(
    mesh: .generateSphere(radius: 0.10 + normalized * 0.04),
    materials: [sunMaterial]
)
sun.name = "SunSource"
sun.position = [0, sourceHeight, 0]
sunlightGroup.addChild(sun)
