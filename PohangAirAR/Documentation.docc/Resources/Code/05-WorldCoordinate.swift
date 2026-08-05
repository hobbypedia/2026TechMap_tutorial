let cameraTransform = arView.session.currentFrame!.camera.transform
let environmentTransform = makeEnvironmentTransform(from: cameraTransform)
let anchor = AnchorEntity(world: environmentTransform)
let root = entityFactory.makeVisualization(from: snapshot)
anchor.addChild(root)
arView.scene.addAnchor(anchor)

func makeEnvironmentTransform(
    from cameraTransform: simd_float4x4
) -> simd_float4x4 {
    var forward = -SIMD3<Float>(
        cameraTransform.columns.2.x,
        0,
        cameraTransform.columns.2.z
    )
    forward = simd_length_squared(forward) < 0.0001
        ? [0, 0, -1]
        : simd_normalize(forward)

    let up = SIMD3<Float>(0, 1, 0)
    let right = simd_normalize(simd_cross(forward, up))
    var transform = matrix_identity_float4x4
    transform.columns.0 = SIMD4<Float>(right.x, right.y, right.z, 0)
    transform.columns.1 = SIMD4<Float>(up.x, up.y, up.z, 0)
    transform.columns.2 = SIMD4<Float>(-forward.x, -forward.y, -forward.z, 0)
    transform.columns.3 = cameraTransform.columns.3
    return transform
}
