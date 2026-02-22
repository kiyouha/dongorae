import Foundation

struct ValidationIssue: Identifiable, Equatable {
    let id = UUID()
    let entity: String
    let field: String
    let message: String
}

enum AppError: LocalizedError, Equatable {
    case validation([ValidationIssue])
    case persistence(String)
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .validation(let issues):
            if issues.isEmpty { return "검증 오류가 발생했습니다." }
            return issues
                .map { "[\($0.entity).\($0.field)] \($0.message)" }
                .joined(separator: "\n")
        case .persistence(let message):
            return message
        case .notFound(let message):
            return message
        }
    }
}

