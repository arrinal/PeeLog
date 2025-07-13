//
//  User.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation
import SwiftData

// MARK: - Authentication Provider
enum AuthProvider: String, Codable, CaseIterable {
    case apple = "apple"
    case email = "email"
    case guest = "guest"
    
    var displayText: String {
        switch self {
        case .apple:
            return "Apple ID"
        case .email:
            return "Email Account"
        case .guest:
            return "Guest Mode"
        }
    }
}

// MARK: - Measurement Unit
enum MeasurementUnit: String, Codable, CaseIterable {
    case metric = "metric"
    case imperial = "imperial"
    
    var displayText: String {
        switch self {
        case .metric:
            return "Metric"
        case .imperial:
            return "Imperial"
        }
    }
}

// MARK: - Theme Preference
enum ThemePreference: String, Codable, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayText: String {
        switch self {
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .system:
            return "System"
        }
    }
}

// MARK: - User Preferences
struct UserPreferences: Codable, Equatable {
    var notificationsEnabled: Bool
    var units: MeasurementUnit
    var theme: ThemePreference
    var syncEnabled: Bool
    
    init(
        notificationsEnabled: Bool = true,
        units: MeasurementUnit = .metric,
        theme: ThemePreference = .system,
        syncEnabled: Bool = true
    ) {
        self.notificationsEnabled = notificationsEnabled
        self.units = units
        self.theme = theme
        self.syncEnabled = syncEnabled
    }
    
    static let `default` = UserPreferences()
}

// MARK: - User Entity
@Model
final class User: Codable {
    var id: UUID
    var email: String?
    var displayName: String?
    var createdAt: Date
    var updatedAt: Date
    var authProvider: AuthProvider
    var appleUserId: String?
    var isGuest: Bool
    
    // User Preferences (stored as encoded data in SwiftData)
    private var preferencesData: Data
    
    var preferences: UserPreferences {
        get {
            do {
                return try JSONDecoder().decode(UserPreferences.self, from: preferencesData)
            } catch {
                return UserPreferences.default
            }
        }
        set {
            do {
                preferencesData = try JSONEncoder().encode(newValue)
                updatedAt = Date()
            } catch {
                // If encoding fails, keep the existing data
                print("Failed to encode user preferences: \(error)")
            }
        }
    }
    
    init(
        email: String? = nil,
        displayName: String? = nil,
        authProvider: AuthProvider,
        appleUserId: String? = nil,
        preferences: UserPreferences = UserPreferences.default
    ) {
        self.id = UUID()
        self.email = email
        self.displayName = displayName
        self.createdAt = Date()
        self.updatedAt = Date()
        self.authProvider = authProvider
        self.appleUserId = appleUserId
        self.isGuest = authProvider == .guest
        
        // Encode preferences
        do {
            self.preferencesData = try JSONEncoder().encode(preferences)
        } catch {
            // Fallback to default preferences if encoding fails
            self.preferencesData = (try? JSONEncoder().encode(UserPreferences.default)) ?? Data()
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Creates a guest user
    static func createGuest() -> User {
        return User(
            displayName: "Guest User",
            authProvider: .guest,
            preferences: UserPreferences.default
        )
    }
    
    /// Creates a user from email/password registration
    static func createEmailUser(email: String, displayName: String? = nil) -> User {
        // Only use email fallback if no display name is provided at all
        // Don't override empty string or whitespace-only names
        let finalDisplayName: String?
        if let displayName = displayName, !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            finalDisplayName = displayName
        } else {
            finalDisplayName = email.components(separatedBy: "@").first
        }
        
        return User(
            email: email,
            displayName: finalDisplayName,
            authProvider: .email,
            preferences: UserPreferences.default
        )
    }
    
    /// Creates a user from Apple Sign In
    static func createAppleUser(appleUserId: String, email: String?, displayName: String?) -> User {
        return User(
            email: email,
            displayName: displayName,
            authProvider: .apple,
            appleUserId: appleUserId,
            preferences: UserPreferences.default
        )
    }
    
    /// Updates user preferences
    func updatePreferences(_ newPreferences: UserPreferences) {
        preferences = newPreferences
    }
    
    /// Updates the authentication provider
    func updateAuthProvider(_ newProvider: AuthProvider) {
        authProvider = newProvider
        updatedAt = Date()
    }
    
    /// Migrates guest user to authenticated user
    func migrateToAuthenticated(email: String?, authProvider: AuthProvider, appleUserId: String? = nil) {
        self.email = email
        self.authProvider = authProvider
        self.appleUserId = appleUserId
        self.isGuest = false
        self.updatedAt = Date()
        
        if displayName == "Guest User" {
            displayName = email?.components(separatedBy: "@").first
        }
    }
    
    // MARK: - Codable Implementation
    
    enum CodingKeys: String, CodingKey {
        case id, email, displayName, createdAt, updatedAt
        case authProvider, appleUserId, isGuest, preferences
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(authProvider, forKey: .authProvider)
        try container.encodeIfPresent(appleUserId, forKey: .appleUserId)
        try container.encode(isGuest, forKey: .isGuest)
        try container.encode(preferences, forKey: .preferences)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(UUID.self, forKey: .id)
        self.email = try container.decodeIfPresent(String.self, forKey: .email)
        self.displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        self.authProvider = try container.decode(AuthProvider.self, forKey: .authProvider)
        self.appleUserId = try container.decodeIfPresent(String.self, forKey: .appleUserId)
        self.isGuest = try container.decode(Bool.self, forKey: .isGuest)
        
        let decodedPreferences = try container.decode(UserPreferences.self, forKey: .preferences)
        self.preferencesData = try JSONEncoder().encode(decodedPreferences)
    }
}

// MARK: - User Extensions

extension User {
    var displayNameOrFallback: String {
        if let displayName = displayName, !displayName.isEmpty {
            return displayName
        }
        
        if let email = email {
            return email.components(separatedBy: "@").first ?? "User"
        }
        
        return authProvider == .guest ? "Guest User" : "User"
    }
    
    var initials: String {
        let name = displayNameOrFallback
        let components = name.components(separatedBy: " ")
        
        if components.count >= 2 {
            let firstInitial = components[0].prefix(1).uppercased()
            let lastInitial = components[1].prefix(1).uppercased()
            return "\(firstInitial)\(lastInitial)"
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
}

// MARK: - AuthProvider Extensions 
 