let cameraTransform = arView.session.currentFrame!.camera.transform
let environmentTransform = makeEnvironmentTransform(from: cameraTransform)
let anchor = AnchorEntity(world: environmentTransform)
let root = entityFactory.makeVisualization(from: snapshot)
anchor.addChild(root)
arView.scene.addAnchor(anchor)

func makeEnvironmentTransform(
    from cameraTransform: simd_float4x4
) -> simd_float4x4 {
    var transform = matrix_identity_float4x4
    transform.columns.3 = cameraTransform.columns.3
    return transform
}
