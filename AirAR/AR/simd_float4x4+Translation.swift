import simd

extension simd_float4x4 {
    /// 단위 행렬에 이동 벡터를 적용한 변환 행렬을 만듭니다.
    init(translation: SIMD3<Float>) {
        self = matrix_identity_float4x4
        columns.3 = SIMD4<Float>(translation.x, translation.y, translation.z, 1)
    }
}
