import ARKit
import Foundation

/// AR 세션과 카메라 추적 상태를 SwiftUI가 이해할 수 있는 값으로 변환합니다.
enum ARSessionState: Equatable, Sendable {
    case initializing
    case trackingNormal
    case limited(String)
    case unavailable
    case interrupted
    case resumed
    case unsupported

    var isReadyForPlacement: Bool {
        self == .trackingNormal
    }

    var message: String {
        switch self {
        case .initializing:
            return "주변을 천천히 비춰 공간을 인식시켜 주세요."
        case .trackingNormal:
            return "공간 인식이 완료되었습니다."
        case let .limited(reason):
            return reason
        case .unavailable:
            return "현재 카메라 위치를 추적할 수 없습니다."
        case .interrupted:
            return "AR 세션이 중단되었습니다."
        case .resumed:
            return "AR 세션을 다시 준비하고 있습니다."
        case .unsupported:
            return "이 기기는 ARKit 월드 트래킹을 지원하지 않습니다."
        }
    }

    static func map(_ trackingState: ARCamera.TrackingState) -> ARSessionState {
        switch trackingState {
        case .normal:
            return .trackingNormal
        case .notAvailable:
            return .unavailable
        case let .limited(reason):
            switch reason {
            case .initializing:
                return .initializing
            case .excessiveMotion:
                return .limited("기기를 너무 빠르게 움직이고 있습니다.")
            case .insufficientFeatures:
                return .limited("주변 특징이 부족합니다. 무늬가 있는 곳을 비춰 주세요.")
            case .relocalizing:
                return .limited("이전 공간을 다시 찾고 있습니다.")
            @unknown default:
                return .limited("공간 추적이 일시적으로 제한되었습니다.")
            }
        }
    }
}
