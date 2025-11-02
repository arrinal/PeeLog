//
//  MigrationController.swift
//  PeeLog
//
//  Created by Arrinal S on 09/08/25.
//

import Foundation

@MainActor
protocol MigrationController {
    func migrateGuestData(guestUser: User, to authenticatedUser: User) async throws
    func skipMigration(authenticatedUser: User) async throws
}



