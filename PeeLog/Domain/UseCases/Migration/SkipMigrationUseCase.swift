//
//  SkipMigrationUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 09/08/25.
//

import Foundation

@MainActor
protocol SkipMigrationUseCaseProtocol {
    func skipMigration(for authenticatedUser: User) async throws
}

@MainActor
final class SkipMigrationUseCase: SkipMigrationUseCaseProtocol {
    private let migrationController: MigrationController
    
    init(migrationController: MigrationController) {
        self.migrationController = migrationController
    }
    
    func skipMigration(for authenticatedUser: User) async throws {
        try await migrationController.skipMigration(authenticatedUser: authenticatedUser)
    }
}



