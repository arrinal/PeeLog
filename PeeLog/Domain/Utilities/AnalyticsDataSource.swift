//
//  AnalyticsDataSource.swift
//  PeeLog
//

import Foundation

enum AnalyticsDataSource: String {
    case remote
    case cache
    case local
}

enum AnalyticsSection: String {
    case overview
    case trends
    case hourly
    case distribution
    case weekly
    case insights
}

// Wraps data with its source (remote/cache/local)
struct Sourced<T>: Sendable where T: Sendable {
    let data: T
    let source: AnalyticsDataSource
}


