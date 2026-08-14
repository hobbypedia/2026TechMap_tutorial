let sunlightGroup = Entity()
sunlightGroup.name = "SunlightGroup"
sunlightGroup.isEnabled = snapshot.isSunVisible()

let normalizedUV = min(max(Float(snapshot.uvIndex / 11), 0), 1)
let beamMaterial = makeUVMaterial(
    normalizedUV: normalizedUV,
    opacity: (0.06 + normalizedUV * 0.36) * 0.26
)

// 교차한 두 평면은 이미지 에셋 대신 Metal 셰이더로 햇빛을 그립니다.
for index in 0..<2 {
    let beam = ModelEntity(
        mesh: .generatePlane(width: 2.8, height: 2.8),
        materials: [beamMaterial]
    )
    beam.name = "SunBeam-" + String(index)
    beam.orientation = simd_quatf(
        angle: Float(index) * .pi / 2,
        axis: [0, 1, 0]
    )
    sunlightGroup.addChild(beam)
}

// 코로나 셰이더 평면은 매 프레임 카메라를 향하게 회전합니다.
let corona = ModelEntity(
    mesh: .generatePlane(width: 0.9, height: 0.9),
    materials: [makeSunCoronaMaterial(normalizedUV: normalizedUV)]
)
corona.name = "SunCorona"
corona.position = [0, 2.4, 0]
sunlightGroup.addChild(corona)
