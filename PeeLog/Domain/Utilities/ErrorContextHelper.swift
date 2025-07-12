//
//  ErrorContextHelper.swift
//  PeeLog
//
//  Created by Arrinal S on 25/06/25.
//

import Foundation

// MARK: - Error Context Helper
struct ErrorContextHelper {
    
    // MARK: - Authentication Context Creation
    
    static func createAuthenticationContext(operation: String, userAction: String? = nil) -> ErrorContext {
        return ErrorContext(
            operation: operation,
            userAction: userAction ?? "User authentication"
        )
    }
    
    static func createEmailSignInContext() -> ErrorContext {
        return createAuthenticationContext(operation: "Email Sign In", userAction: "User sign in attempt")
    }
    
    static func createEmailRegistrationContext() -> ErrorContext {
        return createAuthenticationContext(operation: "Email Registration", userAction: "User registration attempt")
    }
    
    static func createAppleSignInContext() -> ErrorContext {
        return createAuthenticationContext(operation: "Apple Sign In", userAction: "User Apple sign in attempt")
    }
    
    static func createGuestSignInContext() -> ErrorContext {
        return createAuthenticationContext(operation: "Guest Sign In", userAction: "User guest sign in")
    }
    
    static func createSignOutContext() -> ErrorContext {
        return createAuthenticationContext(operation: "Sign Out", userAction: "User sign out")
    }
    
    static func createDeleteAccountContext() -> ErrorContext {
        return createAuthenticationContext(operation: "Delete Account", userAction: "User delete account")
    }
    
    static func createRefreshTokenContext() -> ErrorContext {
        return createAuthenticationContext(operation: "Refresh Token", userAction: "Token refresh")
    }
    
    // MARK: - Profile Management Context Creation
    
    static func createProfileManagementContext(operation: String, userAction: String? = nil) -> ErrorContext {
        return ErrorContext(
            operation: operation,
            userAction: userAction ?? "User profile operation"
        )
    }
    
    static func createProfileContext() -> ErrorContext {
        return createProfileManagementContext(operation: "Profile Management", userAction: "User profile operation")
    }
    
    static func createUserProfileCreationContext() -> ErrorContext {
        return createProfileManagementContext(operation: "Create User Profile", userAction: "User profile creation")
    }
    
    static func createUserProfileUpdateContext() -> ErrorContext {
        return createProfileManagementContext(operation: "Update User Profile", userAction: "User profile update")
    }
    
    static func createUserProfileDeletionContext() -> ErrorContext {
        return createProfileManagementContext(operation: "Delete User Profile", userAction: "User profile deletion")
    }
    
    static func createUpdateUserPreferencesContext() -> ErrorContext {
        return createProfileManagementContext(operation: "Update User Preferences", userAction: "User preferences update")
    }
    
    // MARK: - Data Management Context Creation
    
    static func createDataManagementContext(operation: String, userAction: String? = nil) -> ErrorContext {
        return ErrorContext(
            operation: operation,
            userAction: userAction ?? "User data operation"
        )
    }
    
    static func createMigrateGuestDataContext() -> ErrorContext {
        return createDataManagementContext(operation: "Migrate Guest Data", userAction: "Guest data migration")
    }
    
    // MARK: - Location Context Creation
    
    static func createLocationContext(operation: String, userAction: String? = nil) -> ErrorContext {
        return ErrorContext(
            operation: operation,
            userAction: userAction ?? "Location operation"
        )
    }
    
    static func createLocationPermissionContext() -> ErrorContext {
        return createLocationContext(operation: "request_location_permission", userAction: "Location permission request")
    }
    
    // MARK: - Generic Context Creation
    
    static func createGenericContext(operation: String, userAction: String? = nil, additionalInfo: [String: Any]? = nil) -> ErrorContext {
        return ErrorContext(
            operation: operation,
            userAction: userAction,
            additionalInfo: additionalInfo
        )
    }
} 