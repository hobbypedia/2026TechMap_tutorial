#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
code_root="$repo_root/AirAR/Documentation.docc/Resources/Code"
sdk_path="$(xcrun --sdk iphoneos --show-sdk-path)"
cache_root="$(mktemp -d "${TMPDIR:-/tmp}/airar-tutorial-checkpoints.XXXXXX")"

trap 'rm -rf "$cache_root"' EXIT

common_sources=(
  "$code_root/01-AirARApp.swift"
  "$code_root/02-AirQualityAPIResponse.swift"
  "$code_root/02-AirQualityLevel.swift"
  "$code_root/02-AirQualitySnapshot.swift"
  "$code_root/02-UserLocation.swift"
  "$code_root/02-AirQualityServiceProtocol.swift"
  "$code_root/02-LocationServiceProtocol.swift"
  "$code_root/02-CoreLocationService.swift"
  "$code_root/02-OpenMeteoAirQualityService.swift"
  "$code_root/03-AirQualityMetricViewModel.swift"
  "$code_root/03-AirQualityViewModel.swift"
  "$code_root/03-MetricView.swift"
  "$code_root/03-AirQualityStatusPanel.swift"
)

stage_three_sources=(
  "${common_sources[@]}"
  "$code_root/03-ContentView.swift"
)

stage_four_sources=(
  "${common_sources[@]}"
  "$code_root/04-ARSessionState.swift"
  "$code_root/04-AirQualityVisualizationMapper.swift"
  "$code_root/04-AirQualityEntityFactory.swift"
  "$code_root/04-AirQualityARView.swift"
  "$code_root/04-ContentView.swift"
)

typecheck_checkpoint() {
  local checkpoint_name="$1"
  local module_cache="$cache_root/$checkpoint_name"
  shift

  mkdir -p "$module_cache"
  xcrun --sdk iphoneos swiftc \
    -typecheck \
    -parse-as-library \
    -swift-version 5 \
    -module-name AirAR \
    -module-cache-path "$module_cache" \
    -target arm64-apple-ios18.0 \
    -sdk "$sdk_path" \
    "$@"
}

typecheck_checkpoint "stage-3" "${stage_three_sources[@]}"
echo "3단계 데이터 UI 체크포인트가 컴파일됩니다."

typecheck_checkpoint "stage-4" "${stage_four_sources[@]}"
echo "4단계 AR 파티클 체크포인트가 컴파일됩니다."
