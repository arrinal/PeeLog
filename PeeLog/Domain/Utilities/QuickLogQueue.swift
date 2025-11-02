//
//  QuickLogQueue.swift
//  PeeLog
//
//  Created by Arrinal S on 08/10/25.
//

import Foundation
import WidgetKit

/// Shared queue bridging the widget/AppIntent to the main app via App Group UserDefaults.
enum QuickLogQueue {
    private static let key = "quicklog.queue"

    private static var suite: UserDefaults? {
        let ud = UserDefaults(suiteName: SharedStorage.appGroupId)
        if ud == nil {
            print("[QuickLogQueue] ERROR: failed to open UserDefaults for app group \(SharedStorage.appGroupId)")
        }
        return ud
    }

    private static var fileURL: URL? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedStorage.appGroupId) else {
            print("[QuickLogQueue] ERROR: containerURL is nil for app group \(SharedStorage.appGroupId)")
            return nil
        }
        return container.appendingPathComponent("quicklog_queue.json")
    }

    static func enqueue(payload: [String: Any]) {
        var wroteDefaults = false
        if let suite {
            var current = suite.array(forKey: key) as? [[String: Any]] ?? []
            current.append(payload)
            suite.set(current, forKey: key)
            let verifyCount = (suite.array(forKey: key) as? [[String: Any]])?.count ?? (suite.array(forKey: key)?.count ?? -1)
            wroteDefaults = verifyCount > 0
        }

        if !wroteDefaults {
            // Fallback: append to JSON file in App Group container
            guard let url = fileURL else { return }
            do {
                var arr: [[String: Any]] = []
                if FileManager.default.fileExists(atPath: url.path) {
                    let data = try Data(contentsOf: url)
                    if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        arr = json
                    }
                }
                arr.append(payload)
                let data = try JSONSerialization.data(withJSONObject: arr, options: [])
                try data.write(to: url, options: .atomic)
            } catch {
                // swallow
            }
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func drain() -> [[String: Any]] {
        var collected: [[String: Any]] = []
        if let suite {
            let currentDefaults = suite.array(forKey: key) as? [[String: Any]] ?? []
            suite.removeObject(forKey: key)
            collected.append(contentsOf: currentDefaults)
        }

        // Also drain file fallback
        if let url = fileURL, FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let json = try JSONSerialization.jsonObject(with: data)
                let arr = (json as? [[String: Any]]) ?? []
                try FileManager.default.removeItem(at: url)
                collected.append(contentsOf: arr)
            } catch {
                // swallow
            }
        }
        return collected
    }
}



