#include <metal_stdlib>
#include <RealityKit/RealityKit.h>

using namespace metal;

/// 이미지 없이 UV 좌표만으로 따뜻한 햇빛 빔과 투명도 변화를 만듭니다.
[[visible]]
void uvBeamSurface(realitykit::surface_parameters params) {
    float2 uv = params.geometry().uv0();
    float strength = saturate(params.uniforms().custom_parameter()[0]);
    float baseOpacity = saturate(params.uniforms().custom_parameter()[1]);

    float distanceFromSource = 1.0 - uv.y;
    float halfWidth = mix(0.028, 0.50, distanceFromSource);
    float horizontalDistance = abs(uv.x - 0.5);
    float edgeSoftness = mix(0.014, 0.085, distanceFromSource);
    float beamMask = 1.0 - smoothstep(
        max(halfWidth - edgeSoftness, 0.0),
        halfWidth,
        horizontalDistance
    );

    float sourceFade = smoothstep(0.0, 0.045, distanceFromSource);
    float tailFade = 1.0 - smoothstep(0.54, 1.0, distanceFromSource);
    float shimmer = 0.92
        + 0.08 * sin(params.uniforms().time() * 1.35 + distanceFromSource * 8.0);
    float opacity = beamMask * sourceFade * tailFade * shimmer * baseOpacity;

    float centerRatio = 1.0 - saturate(horizontalDistance / max(halfWidth, 0.001));
    half3 warmEdge = half3(1.0, 0.70, 0.30);
    half3 whiteCore = half3(1.25, 1.18, 0.92);
    half3 sunlight = mix(warmEdge, whiteCore, half(smoothstep(0.0, 0.82, centerRatio)));
    params.surface().set_base_color(sunlight * half(mix(0.86, 1.18, strength)));
    params.surface().set_opacity(opacity);
}

/// 흰 중심광, 금빛 코로나와 길이가 서로 다른 뾰족한 광선을 절차적으로 만듭니다.
[[visible]]
void sunCoronaSurface(realitykit::surface_parameters params) {
    float2 centeredUV = (params.geometry().uv0() - 0.5) * 2.0;
    float radius = length(centeredUV);
    float strength = saturate(params.uniforms().custom_parameter()[0]);
    float baseOpacity = saturate(params.uniforms().custom_parameter()[1]);
    float time = params.uniforms().time();
    float angle = atan2(centeredUV.y, centeredUV.x);

    float whiteDisk = 1.0 - smoothstep(0.0, 0.22, radius);
    float innerGlow = (1.0 - smoothstep(0.06, 0.50, radius)) * 0.92;
    float outerGlow = (1.0 - smoothstep(0.28, 0.96, radius)) * 0.42;

    // 좁고 긴 여러 주기의 피크를 합쳐 둥근 구보다 강한 태양 코로나가 먼저 보이게 합니다.
    float major = pow(saturate(0.5 + 0.5 * cos(angle * 8.0 + time * 0.045)), 42.0);
    float medium = pow(saturate(0.5 + 0.5 * sin(angle * 17.0 - time * 0.065)), 28.0);
    float fine = pow(saturate(0.5 + 0.5 * cos(angle * 31.0 + time * 0.09)), 36.0);
    float irregular = 0.72 + 0.28 * sin(angle * 5.0 + sin(angle * 11.0));
    float rayEnvelope = smoothstep(0.14, 0.24, radius)
        * (1.0 - smoothstep(0.72, 1.0, radius));
    float rays = (major * 0.86 + medium * 0.50 + fine * 0.25)
        * irregular
        * rayEnvelope
        * mix(0.78, 1.18, strength);

    float pulse = 0.965 + 0.035 * sin(time * 1.05);
    float opacity = saturate(whiteDisk + innerGlow + outerGlow + rays) * baseOpacity * pulse;
    half3 hotWhite = half3(1.35, 1.28, 1.04);
    half3 solarGold = half3(1.12, 0.62, 0.12);
    half3 coronaColor = mix(solarGold, hotWhite, half(saturate(whiteDisk + innerGlow * 0.72)));
    params.surface().set_base_color(coronaColor);
    params.surface().set_opacity(opacity);
}
