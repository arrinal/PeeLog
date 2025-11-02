//
//  AnalyticsLogger.swift
//  PeeLog
//

import Foundation

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

enum AnalyticsLogger {
    static func logQuickLog(mode: String, source: String, quality: PeeQuality) {
        #if canImport(FirebaseAnalytics)
        let params: [String: Any] = [
            "mode": mode,            // "with_loc" | "no_loc"
            "source": source,        // "deeplink_widget" | "widget_appintent"
            "quality": quality.analyticsCode // "clear"|"pale"|"yellow"|"dark"|"amber"
        ]
        Analytics.logEvent("quicklog_add", parameters: params)
        #endif
    }
}

extension PeeQuality {
    var analyticsCode: String {
        switch self {
        case .clear: return "clear"
        case .paleYellow: return "pale"
        case .yellow: return "yellow"
        case .darkYellow: return "dark"
        case .amber: return "amber"
        }
    }
}


