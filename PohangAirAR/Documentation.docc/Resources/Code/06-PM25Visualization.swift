let texture = try? TextureResource.load(named: "DustParticle")
var material = UnlitMaterial()
material.color = .init(
    tint: UIColor(red: 0.76, green: 0.58, blue: 0.25, alpha: 1),
    texture: texture.map { resource in .init(resource) }
)
material.blending = .transparent(opacity: 0.33)

let count = pm25 >= 76
    ? min(96 + Int(((pm25 - 76) * 0.65).rounded()), 144)
    : min(max(Int((max(pm25, 0) * 1.6).rounded()), 8), 72)
let sizePattern: [Float] = [0.21, 0.25, 0.29, 0.34, 0.39]
for index in 0..<count {
    let size = sizePattern[(index * 7) % sizePattern.count]
    let particle = ModelEntity(
        mesh: .generatePlane(width: size, height: size),
        materials: [material]
    )
    particle.name = "DustParticle-" + String(index)
    particle.position = particlePosition(index: index, pm25: pm25)
    dustField.addChild(particle)
}

func particlePosition(index: Int, pm25: Double) -> SIMD3<Float> {
    let seed = UInt64(max(0, Int((pm25 * 10).rounded())))
        + UInt64(index * 1_103)
    let azimuthSeed = Float((seed * 1_664_525 + 1_013_904_223) % 10_000) / 9_999
    let radiusSeed = Float((seed * 1_103_515_245 + 12_345) % 10_000) / 9_999
    let heightSeed = Float((seed * 22_695_477 + 1) % 10_000) / 9_999
    let severe = pm25 >= 76
    let azimuth = azimuthSeed * 2 * Float.pi
    let radius = (severe ? 0.55 : 0.7) + radiusSeed * (severe ? 1.65 : 1.3)
    let height: Float = severe ? 1.5 : 1.1
    return [
        cos(azimuth) * radius,
        (heightSeed - 0.5) * height,
        sin(azimuth) * radius
    ]
}
