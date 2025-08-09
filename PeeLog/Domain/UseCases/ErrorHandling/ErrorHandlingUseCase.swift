//
//  ErrorHandlingUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation

// MARK: - Common App Errors
enum AppError: Error, LocalizedError, Equatable {
    case networkError(String)
    case dataCorruption(String)
    case invalidInput(String)
    case permissionDenied(String)
    case serviceUnavailable(String)
    case timeout(String)
    case unknown(String)
    
    // Location specific errors
    case locationError(LocationError)
    
    // Data persistence errors
    case saveFailed(String)
    case loadFailed(String)
    case deleteFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network Error: \(message)"
        case .dataCorruption(let message):
            return "Data Corruption: \(message)"
        case .invalidInput(let message):
            return "Invalid Input: \(message)"
        case .permissionDenied(let message):
            return "Permission Denied: \(message)"
        case .serviceUnavailable(let message):
            return "Service Unavailable: \(message)"
        case .timeout(let message):
            return "Timeout: \(message)"
        case .unknown(let message):
            return "\(message)"
        case .locationError(let locationError):
            return locationError.errorDescription
        case .saveFailed(let message):
            return "Save Failed: \(message)"
        case .loadFailed(let message):
            return "Load Failed: \(message)"
        case .deleteFailed(let message):
            return "Delete Failed: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Check your internet connection and try again."
        case .dataCorruption:
            return "The app data may be corrupted. Consider restarting the app."
        case .invalidInput:
            return "Please check your input and try again."
        case .permissionDenied:
            return "Please enable the required permissions in Settings."
        case .serviceUnavailable:
            return "The service is temporarily unavailable. Please try again later."
        case .timeout:
            return "The operation timed out. Please try again."
        case .unknown:
            return "An unexpected error occurred. Please try again or restart the app."
        case .locationError(let locationError):
            return locationError.recoverySuggestion
        case .saveFailed:
            return "Failed to save data. Please try again or check available storage."
        case .loadFailed:
            return "Failed to load data. Please restart the app or check data integrity."
        case .deleteFailed:
            return "Failed to delete data. Please try again."
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .dataCorruption, .saveFailed:
            return .critical
        case .permissionDenied, .serviceUnavailable:
            return .high
        case .networkError, .timeout, .loadFailed:
            return .medium
        case .invalidInput, .deleteFailed:
            return .low
        case .locationError(let locationError):
            switch locationError {
            case .permissionDenied, .permissionRestricted:
                return .high
            case .serviceUnavailable:
                return .medium
            default:
                return .low
            }
        case .unknown:
            return .medium
        }
    }
    
    var shouldShowToUser: Bool {
        switch severity {
        case .critical, .high:
            return true
        case .medium:
            return true
        case .low:
            return false
        }
    }
}

enum ErrorSeverity: Int, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4
    
    var description: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
}

// MARK: - Error Recovery Strategy
enum ErrorRecoveryStrategy {
    case retry
    case fallback
    case userAction
    case ignore
    case restart
    
    var description: String {
        switch self {
        case .retry: return "Retry the operation"
        case .fallback: return "Use fallback method"
        case .userAction: return "Requires user action"
        case .ignore: return "Ignore and continue"
        case .restart: return "Restart required"
        }
    }
}

// MARK: - Error Context
struct ErrorContext {
    let operation: String
    let timestamp: Date
    let userAction: String?
    let additionalInfo: [String: Any]?
    
    init(operation: String, userAction: String? = nil, additionalInfo: [String: Any]? = nil) {
        self.operation = operation
        self.userAction = userAction
        self.additionalInfo = additionalInfo
        self.timestamp = Date()
    }
}

// MARK: - Error Handling Result
struct ErrorHandlingResult {
    let error: AppError
    let context: ErrorContext
    let recoveryStrategy: ErrorRecoveryStrategy
    let userMessage: String
    let shouldLog: Bool
    let shouldReport: Bool
    
    init(error: AppError, context: ErrorContext, recoveryStrategy: ErrorRecoveryStrategy, userMessage: String, shouldLog: Bool = true, shouldReport: Bool = false) {
        self.error = error
        self.context = context
        self.recoveryStrategy = recoveryStrategy
        self.userMessage = userMessage
        self.shouldLog = shouldLog
        self.shouldReport = shouldReport
    }
}

// MARK: - Error Handling Use Case Protocol
protocol ErrorHandlingUseCase {
    func handleError(_ error: Error, context: ErrorContext) -> ErrorHandlingResult
    func mapError(_ error: Error) -> AppError
    func determineRecoveryStrategy(for error: AppError, context: ErrorContext) -> ErrorRecoveryStrategy
    func generateUserMessage(for error: AppError, strategy: ErrorRecoveryStrategy) -> String
    func shouldRetry(_ error: AppError, attemptCount: Int) -> Bool
}

// MARK: - Error Handling Use Case Implementation
class ErrorHandlingUseCaseImpl: ErrorHandlingUseCase {
    private let maxRetryAttempts = 3
    
    func handleError(_ error: Error, context: ErrorContext) -> ErrorHandlingResult {
        let appError = mapError(error)
        let recoveryStrategy = determineRecoveryStrategy(for: appError, context: context)
        let userMessage = generateUserMessage(for: appError, strategy: recoveryStrategy)
        
        let shouldLog = appError.severity.rawValue >= ErrorSeverity.medium.rawValue
        let shouldReport = appError.severity == .critical
        
        return ErrorHandlingResult(
            error: appError,
            context: context,
            recoveryStrategy: recoveryStrategy,
            userMessage: userMessage,
            shouldLog: shouldLog,
            shouldReport: shouldReport
        )
    }
    
    func mapError(_ error: Error) -> AppError {
        // Map various error types to AppError
        switch error {
        case let appError as AppError:
            return appError
            
        case let locationError as LocationError:
            return .locationError(locationError)
            
        case let urlError as URLError:
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkError("No internet connection")
            case .timedOut:
                return .timeout("Network request timed out")
            case .cannotFindHost, .cannotConnectToHost:
                return .networkError("Cannot connect to server")
            default:
                return .networkError(urlError.localizedDescription)
            }
            
        case CocoaError.fileReadCorruptFile, CocoaError.fileReadUnknownStringEncoding:
            return .dataCorruption("File data is corrupted")
            
        case CocoaError.fileWriteNoPermission, CocoaError.fileReadNoPermission:
            return .permissionDenied("File access permission denied")
            
        case CocoaError.fileWriteVolumeReadOnly, CocoaError.fileWriteFileExists:
            return .saveFailed("Cannot save file: \(error.localizedDescription)")
            
        default:
            return .unknown(error.localizedDescription)
        }
    }
    
    func determineRecoveryStrategy(for error: AppError, context: ErrorContext) -> ErrorRecoveryStrategy {
        switch error {
        case .networkError, .timeout:
            return .retry
            
        case .permissionDenied, .locationError(.permissionDenied), .locationError(.permissionRestricted):
            return .userAction
            
        case .serviceUnavailable, .locationError(.serviceUnavailable):
            return .fallback
            
        case .dataCorruption:
            return .restart
            
        case .invalidInput:
            return .ignore
            
        case .saveFailed, .loadFailed, .deleteFailed:
            return .retry
            
        case .locationError(.timeout), .locationError(.locationUnavailable):
            return .retry
            
        case .unknown:
            return .fallback
            
        default:
            return .retry
        }
    }
    
    func generateUserMessage(for error: AppError, strategy: ErrorRecoveryStrategy) -> String {
        let baseMessage = error.errorDescription ?? "An error occurred"
        let recoveryMessage = error.recoverySuggestion ?? ""
        
        var message = baseMessage
        
        if !recoveryMessage.isEmpty {
            message += "\n\n\(recoveryMessage)"
        }
        
        switch strategy {
        case .retry:
            message += "\n\nThe app will try again automatically."
        case .userAction:
            message += "\n\nPlease take action and try again."
        case .fallback:
            message += "\n\nUsing alternative method."
        case .restart:
            message += "\n\nPlease restart the app."
        case .ignore:
            message += "\n\nYou can continue using the app."
        }
        
        return message
    }
    
    func shouldRetry(_ error: AppError, attemptCount: Int) -> Bool {
        guard attemptCount < maxRetryAttempts else { return false }
        
        switch error {
        case .networkError, .timeout, .saveFailed, .loadFailed:
            return true
        case .locationError(.timeout), .locationError(.locationUnavailable):
            return true
        case .serviceUnavailable:
            return attemptCount < 2 // Fewer retries for service issues
        default:
            return false
        }
    }
} 
