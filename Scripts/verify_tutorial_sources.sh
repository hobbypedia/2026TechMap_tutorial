#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
code_root="$repository_root/AirAR/Documentation.docc/Resources/Code"

verify_copy() {
    local source_path="$repository_root/$1"
    local tutorial_path="$code_root/$2"

    if ! cmp -s "$source_path" "$tutorial_path"; then
        echo "튜토리얼 코드가 실제 소스와 다릅니다: $2" >&2
        echo "기준 파일: $1" >&2
        exit 1
    fi
}

verify_copy "AirAR/App/AirARApp.swift" "01-AirARApp.swift"

verify_copy "AirAR/Models/AirQualityAPIResponse.swift" "02-AirQualityAPIResponse.swift"
verify_copy "AirAR/Models/AirQualityLevel.swift" "02-AirQualityLevel.swift"
verify_copy "AirAR/Models/AirQualitySnapshot.swift" "02-AirQualitySnapshot.swift"
verify_copy "AirAR/Models/UserLocation.swift" "02-UserLocation.swift"
verify_copy "AirAR/Services/AirQualityServiceProtocol.swift" "02-AirQualityServiceProtocol.swift"
verify_copy "AirAR/Services/LocationServiceProtocol.swift" "02-LocationServiceProtocol.swift"
verify_copy "AirAR/Services/CoreLocationService.swift" "02-CoreLocationService.swift"
verify_copy "AirAR/Services/OpenMeteoAirQualityService.swift" "02-OpenMeteoAirQualityService.swift"

verify_copy "AirAR/ViewModels/AirQualityMetricViewModel.swift" "03-AirQualityMetricViewModel.swift"
verify_copy "AirAR/ViewModels/AirQualityViewModel.swift" "03-AirQualityViewModel.swift"
verify_copy "AirAR/Views/MetricView.swift" "03-MetricView.swift"
verify_copy "AirAR/Views/AirQualityStatusPanel.swift" "03-AirQualityStatusPanel.swift"

verify_copy "AirAR/AR/ARSessionState.swift" "04-ARSessionState.swift"
verify_copy "AirAR/Views/ContentView.swift" "04-ContentView.swift"

verify_copy "AirAR/AR/AirQualityVisualizationMapper.swift" "05-AirQualityVisualizationMapper.swift"
verify_copy "AirAR/AR/simd_float4x4+Translation.swift" "05-simd_float4x4+Translation.swift"
verify_copy "AirAR/AR/AirQualityEntityFactory.swift" "05-AirQualityEntityFactory.swift"
verify_copy "AirAR/AR/AirQualityARView.swift" "05-AirQualityARView.swift"
verify_copy "AirAR/AR/SolarLensFlareView.swift" "05-SolarLensFlareView.swift"
verify_copy "AirAR/AR/UVBeamShader.metal" "05-UVBeamShader.metal"


echo "튜토리얼 최종 코드와 실제 프로젝트 소스가 일치합니다."
