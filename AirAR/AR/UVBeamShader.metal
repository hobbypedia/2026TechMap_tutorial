#include <metal_stdlib>
#include <RealityKit/RealityKit.h>

using namespace metal;

/// 이미지 없이 UV 좌표만으로 따뜻한 햇빛 빔과 투명도 변화를 만듭니다.
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
    float shimmer = 0.94
        + 0.06 * sin(params.uniforms().time() * 1.35 + distanceFromSource * 8.0);
    float opacity = beamMask
        * sourceFade
        * tailFade
        * shimmer
        * baseOpacity;

    float centerRatio = 1.0 - saturate(horizontalDistance / max(halfWidth, 0.001));
    half3 warmEdge = half3(1.0, 0.78, 0.50);
    half3 whiteCore = half3(1.0, 0.97, 0.84);
    half3 sunlight = mix(warmEdge, whiteCore, half(smoothstep(0.0, 0.85, centerRatio)));
    half brightness = half(mix(0.84, 1.0, strength));
    params.surface().set_base_color(sunlight * brightness);
    params.surface().set_opacity(opacity);
}

/// 태양 구 주위에 흰 중심광, 금빛 코로나와 길이가 다른 광선을 절차적으로 만듭니다.
[[visible]]
void sunCoronaSurface(realitykit::surface_parameters params) {
    float2 centeredUV = (params.geometry().uv0() - 0.5) * 2.0;
    float radius = length(centeredUV);
    float strength = saturate(params.uniforms().custom_parameter()[0]);
    float baseOpacity = saturate(params.uniforms().custom_parameter()[1]);
    float time = params.uniforms().time();

    float angle = atan2(centeredUV.y, centeredUV.x);
    float core = 1.0 - smoothstep(0.0, 0.34, radius);
    float innerGlow = (1.0 - smoothstep(0.08, 0.62, radius)) * 0.78;
    float outerGlow = (1.0 - smoothstep(0.30, 1.0, radius)) * 0.34;

    // 서로 다른 주기의 날카로운 무늬를 더해 완벽한 원이 아닌 태양 코로나를 만듭니다.
    float rayPatternA = pow(saturate(0.5 + 0.5 * cos(angle * 14.0 + time * 0.10)), 14.0);
    float rayPatternB = pow(saturate(0.5 + 0.5 * sin(angle * 23.0 - time * 0.07)), 20.0);
    float rayEnvelope = smoothstep(0.18, 0.34, radius)
        * (1.0 - smoothstep(0.48, 1.0, radius));
    float rays = (rayPatternA * 0.34 + rayPatternB * 0.22)
        * rayEnvelope
        * mix(0.72, 1.0, strength);

    float pulse = 0.96 + 0.04 * sin(time * 1.15);
    float opacity = saturate(core + innerGlow + outerGlow + rays) * baseOpacity * pulse;
    half3 warmCorona = half3(1.0, 0.63, 0.20);
    half3 whiteHot = half3(1.0, 0.99, 0.88);
    half centerMix = half(saturate(core + innerGlow * 0.62));
    params.surface().set_base_color(mix(warmCorona, whiteHot, centerMix));
    params.surface().set_opacity(opacity);
}
