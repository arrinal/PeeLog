//
//  SyncControl.swift
//  PeeLog
//
//  Created by Arrinal S on 10/08/25.
//

import Foundation

@MainActor
final class SyncControl {
    var isBlocked: Bool = false
    var lastSuccessfulSyncAt: Date?
}
