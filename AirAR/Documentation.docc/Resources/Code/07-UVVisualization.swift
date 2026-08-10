import Metal
import RealityKit

let device = MTLCreateSystemDefaultDevice()
let library = device?.makeDefaultLibrary()
let surfaceShader = library.map {
    CustomMaterial.SurfaceShader(named: "uvBeamSurface", in: $0)
}

let normalized = min(max(Float(uvIndex / 11), 0), 1)
let opacity = (0.06 + normalized * 0.36) * 0.35

guard let surfaceShader,
      var material = try? CustomMaterial(
        surfaceShader: surfaceShader,
        lightingModel: .unlit
      ) else {
    return
}

// Metal의 custom_parameter()[0]과 [1]에서 읽습니다.
material.custom.value = [normalized, opacity, 0, 0]
material.blending = .transparent(opacity: .init(floatLiteral: 1.0))
material.faceCulling = .none

let uvGroup = Entity()
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
    let beam = ModelEntity(
        mesh: .generatePlane(width: size, height: size),
        materials: [material]
    )
    beam.name = "UVBeam-" + String(index)
    beam.position = yawRotation.act([0, centerHeight, -radialOffset])
    beam.orientation = yawRotation * tiltRotation
    uvGroup.addChild(beam)
}
