import Foundation

/// Basic error handling for all services
enum AppError: Error, LocalizedError {
    case networkError(String)
    case authenticationError(String)
    case storageError(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message), 
             .authenticationError(let message), 
             .storageError(let message), 
             .unknown(let message):
            return message
        }
    }
}

/// Keep these EMPTY for now. Add methods later without touching views.
protocol AuthServicing {}
protocol LocalStore {}
protocol APIClient {}
