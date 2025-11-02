//
//  AppNotifications.swift
//  PeeLog
//
//  Created by Arrinal S on 09/08/25.
//

import Foundation

extension Notification.Name {
    static let eventsDidSync = Notification.Name("eventsDidSync")
    static let requestInitialFullSync = Notification.Name("requestInitialFullSync")
    static let serverStatusToast = Notification.Name("serverStatusToast")
    static let eventsStoreWillReset = Notification.Name("eventsStoreWillReset")
    static let eventsStoreDidReset = Notification.Name("eventsStoreDidReset")
}


