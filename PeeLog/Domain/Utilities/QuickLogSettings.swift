//
//  QuickLogSettings.swift
//  PeeLog
//

import Foundation

enum QuickLogSettings {
    private static let keyUseLiveLocation = "quickLogUseLiveLocation"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: SharedStorage.appGroupId)
    }

    static func readUseLiveLocation() -> Bool {
        guard let defaults else { return false }
        return defaults.bool(forKey: keyUseLiveLocation)
    }

    static func writeUseLiveLocation(_ value: Bool) {
        guard let defaults else { return }
        defaults.set(value, forKey: keyUseLiveLocation)
    }
}


