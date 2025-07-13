//
//  FirebaseAuthService.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation
@preconcurrency import FirebaseAuth
import Combine
import AuthenticationServices
import CryptoKit

// MARK: - Firebase Auth Service
@MainActor
final class FirebaseAuthService: ObservableObject {
    @Published private(set) var currentFirebaseUser: FirebaseAuth.User?
    @Published private(set) var isSignedIn = false
    
    // Apple Sign In properties
    private var currentNonce: String?
    
    init() {
        updateAuthState()
    }
    
    // MARK: - Auth State Management
    
    private func updateAuthState() {
        currentFirebaseUser = Auth.auth().currentUser
        isSignedIn = currentFirebaseUser != nil
    }
    
    // MARK: - Email/Password Authentication
    
    func signInWithEmail(_ email: String, password: String) async throws -> FirebaseAuth.User {
        do {
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            
            // Check if email is verified
            if !authResult.user.isEmailVerified {
                // Sign out the user since they're not verified
                try Auth.auth().signOut()
                throw AuthError.emailNotVerified
            }
            
            updateAuthState()
            return authResult.user
        } catch {
            // If it's already an AuthError, don't map it
            if let authError = error as? AuthError {
                throw authError
            }
            throw mapFirebaseError(error)
        }
    }
    
    func createUserWithEmail(_ email: String, password: String) async throws -> FirebaseAuth.User {
        do {
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            updateAuthState()
            return authResult.user
        } catch {
            throw mapFirebaseError(error)
        }
    }
    
    // MARK: - Email Verification
    
    func sendEmailVerification() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.userNotFound
        }
        
        do {
            try await user.sendEmailVerification()
        } catch {
            throw mapFirebaseError(error)
        }
    }
    
    func sendEmailVerification(toEmail email: String, password: String) async throws {
        do {
            // Temporarily sign in the user to send verification email
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            
            // Send verification email
            try await authResult.user.sendEmailVerification()
            
            // Sign out the user again since they're not verified yet
            try Auth.auth().signOut()
        } catch {
            // If it's already an AuthError, don't map it
            if let authError = error as? AuthError {
                throw authError
            }
            throw mapFirebaseError(error)
        }
    }
    
    func sendEmailVerification(to user: FirebaseAuth.User) async throws {
        do {
            try await user.sendEmailVerification()
        } catch {
            throw mapFirebaseError(error)
        }
    }
    
    func isEmailVerified() -> Bool {
        guard let user = Auth.auth().currentUser else {
            return false
        }
        return user.isEmailVerified
    }
    
    func reloadUser() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.userNotFound
        }
        
        do {
            try await user.reload()
            updateAuthState()
        } catch {
            throw mapFirebaseError(error)
        }
    }
    
    func checkEmailVerificationStatus() async throws -> Bool {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.userNotFound
        }
        
        do {
            try await user.reload()
            updateAuthState()
            return user.isEmailVerified
        } catch {
            throw mapFirebaseError(error)
        }
    }
    
    func checkEmailVerificationStatus(email: String, password: String) async throws -> Bool {
        do {
            // Temporarily sign in to check verification status
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            
            // Reload user to get fresh verification status
            try await authResult.user.reload()
            
            let isVerified = authResult.user.isEmailVerified
            
            // Sign out the user if not verified
            if !isVerified {
                try Auth.auth().signOut()
            }
            
            return isVerified
        } catch {
            throw mapFirebaseError(error)
        }
    }

    // MARK: - Password Reset
    
    func sendPasswordReset(toEmail email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            throw mapFirebaseError(error)
        }
    }
    
    // MARK: - Apple Sign In Implementation
    
    func signInWithApple() async throws -> FirebaseAuth.User {
        // Generate nonce for security
        let nonce = randomNonceString()
        currentNonce = nonce
        
        // Create Apple ID authorization request
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        // Perform authorization request
        let authorizationResult = try await performAppleSignIn(request: request)
        
        // Get Apple ID credential from result
        guard let appleIDCredential = authorizationResult.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.invalidCredentials
        }
        
        // Create Firebase credential
        let firebaseCredential = OAuthProvider.credential(
            withProviderID: "apple.com",
            idToken: idTokenString,
            rawNonce: nonce
        )
        
        // Sign in to Firebase with Apple credential
        do {
            let authResult = try await Auth.auth().signIn(with: firebaseCredential)
            
            // Update display name if available and not already set
            if let fullName = appleIDCredential.fullName,
               let firstName = fullName.givenName,
               let lastName = fullName.familyName,
               authResult.user.displayName?.isEmpty ?? true {
                
                let displayName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
                if !displayName.isEmpty {
                    try await updateDisplayName(displayName)
                }
            }
            
            updateAuthState()
            return authResult.user
            
        } catch {
            throw mapFirebaseError(error)
        }
    }
    
    // MARK: - Apple Sign In Helper Methods
    
    private func performAppleSignIn(request: ASAuthorizationRequest) async throws -> ASAuthorization {
        return try await withCheckedThrowingContinuation { continuation in
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            
            let delegate = AppleSignInDelegate { result in
                continuation.resume(with: result)
            }
            
            authorizationController.delegate = delegate
            authorizationController.presentationContextProvider = delegate
            authorizationController.performRequests()
            
            // Keep delegate alive during the operation
            objc_setAssociatedObject(
                authorizationController,
                "delegate",
                delegate,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    // MARK: - Sign Out & Account Management
    
    func signOut() async throws {
        do {
            try Auth.auth().signOut()
            updateAuthState()
        } catch {
            throw mapFirebaseError(error)
        }
    }
    
    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.userNotFound
        }
        
        do {
            try await user.delete()
            updateAuthState()
        } catch {
            throw mapFirebaseError(error)
        }
    }
    
    // MARK: - Token Management
    
    func getIDToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.noToken
        }
        
        do {
            return try await user.getIDToken()
        } catch {
            throw mapFirebaseError(error)
        }
    }
    
    func refreshToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.noRefreshToken
        }
        
        do {
            return try await user.getIDToken(forcingRefresh: true)
        } catch {
            throw mapFirebaseError(error)
        }
    }
    
    func isTokenValid() async -> Bool {
        guard let user = Auth.auth().currentUser else {
            return false
        }
        
        do {
            _ = try await user.getIDToken()
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Profile Updates
    
    func updateDisplayName(_ displayName: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.userNotFound
        }
        
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = displayName
        
        do {
            try await changeRequest.commitChanges()
            print("✅ Firebase Auth: Successfully updated display name to '\(displayName)'")
        } catch {
            print("❌ Firebase Auth: Failed to update display name to '\(displayName)': \(error)")
            throw mapFirebaseError(error)
        }
    }
    
    func updateEmail(_ email: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.userNotFound
        }
        
        do {
            // Use the newer email verification flow instead of direct update
            try await user.sendEmailVerification(beforeUpdatingEmail: email)
        } catch {
            throw mapFirebaseError(error)
        }
    }
    
    // MARK: - Utility Methods
    
    func getCurrentUser() -> FirebaseAuth.User? {
        let user = Auth.auth().currentUser
        if let user = user {
            print("🔍 Firebase Auth: Current user - Email: \(user.email ?? "nil"), Display Name: '\(user.displayName ?? "nil")', UID: \(user.uid)")
        }
        return user
    }
    
    // MARK: - Error Mapping
    
    private func mapFirebaseError(_ error: Error) -> AuthError {
        guard let authError = error as? AuthErrorCode else {
            return .unknown(error.localizedDescription)
        }
        
        switch authError.code {
        case .invalidEmail:
            return .invalidEmail
        case .userNotFound:
            return .userNotFound
        case .wrongPassword:
            return .invalidCredentials
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .weakPassword:
            return .weakPassword
        case .userDisabled:
            return .userDisabled
        case .tooManyRequests:
            return .tooManyRequests
        case .networkError:
            return .networkError("Network connection error")
        case .operationNotAllowed:
            return .serviceUnavailable
        default:
            return .unknown(authError.localizedDescription)
        }
    }
}

// MARK: - Apple Sign In Delegate

@MainActor
final class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let completion: (Result<ASAuthorization, Error>) -> Void
    
    init(completion: @escaping (Result<ASAuthorization, Error>) -> Void) {
        self.completion = completion
    }
    
    // MARK: - ASAuthorizationControllerDelegate
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        completion(.success(authorization))
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(error))
    }
    
    // MARK: - ASAuthorizationControllerPresentationContextProviding
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("Unable to get window for Apple Sign In presentation")
        }
        return window
    }
} 