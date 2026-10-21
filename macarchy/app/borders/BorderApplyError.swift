import Foundation

struct BorderApplyError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
