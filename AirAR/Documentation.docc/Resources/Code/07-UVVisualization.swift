let normalized = min(max(Float(uvIndex / 11), 0), 1)
let texture = try? TextureResource.load(named: "UVSpectrum")
var material = UnlitMaterial()
material.color = .init(
    tint: .white,
    texture: texture.map { resource in .init(resource) }
)
let opacity = (0.06 + normalized * 0.36) * 0.35
material.blending = .transparent(opacity: opacity)

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
    let spectrum = ModelEntity(
        mesh: .generatePlane(width: size, height: size),
        materials: [material]
    )
    spectrum.name = "UVSpectrum-" + String(index)
    spectrum.position = yawRotation.act([0, centerHeight, -radialOffset])
    spectrum.orientation = yawRotation * tiltRotation
    uvGroup.addChild(spectrum)
}
