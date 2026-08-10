#include <metal_stdlib>
#include <RealityKit/RealityKit.h>

using namespace metal;

/// 0...1 위치를 빨강에서 보라까지 이어지는 스펙트럼 색으로 변환합니다.
static half3 spectrumColor(float position) {
    float3 offsets = float3(0.0, 4.0, 2.0) / 6.0;
    float3 rgb = saturate(
        abs(fract(position + offsets) * 6.0 - 3.0) - 1.0
    );
    return half3(rgb);
}

/// 이미지 없이 UV 좌표만으로 삼각형 빔, 스펙트럼과 투명도 변화를 만듭니다.
[[visible]]
void uvBeamSurface(realitykit::surface_parameters params) {
    float2 uv = params.geometry().uv0();
    float strength = saturate(params.uniforms().custom_parameter()[0]);
    float baseOpacity = saturate(params.uniforms().custom_parameter()[1]);

    // 평면 위쪽 중앙을 광원으로 보고 아래로 갈수록 빔을 넓힙니다.
    float distanceFromSource = 1.0 - uv.y;
    float halfWidth = mix(0.035, 0.50, distanceFromSource);
    float horizontalDistance = abs(uv.x - 0.5);
    float edgeSoftness = mix(0.018, 0.07, distanceFromSource);
    float beamMask = 1.0 - smoothstep(
        max(halfWidth - edgeSoftness, 0.0),
        halfWidth,
        horizontalDistance
    );

    float sourceFade = smoothstep(0.0, 0.055, distanceFromSource);
    float tailFade = 1.0 - smoothstep(0.58, 1.0, distanceFromSource);
    float spectrumPosition = saturate(
        (uv.x - (0.5 - halfWidth)) / max(halfWidth * 2.0, 0.001)
    );
    float shimmer = 0.94
        + 0.06 * sin(params.uniforms().time() * 1.35 + distanceFromSource * 8.0);
    float opacity = beamMask
        * sourceFade
        * tailFade
        * shimmer
        * baseOpacity;

    half brightness = half(mix(0.82, 1.0, strength));
    params.surface().set_base_color(spectrumColor(spectrumPosition) * brightness);
    params.surface().set_opacity(opacity);
}
