//
//  QuickLogWidget.swift
//  PeeLogWidgetExtension
//
//  Moved from PeeLog/Presentation/Widgets for organization.
//

import WidgetKit
import SwiftUI
import AppIntents
import CoreLocation

// MARK: - One-shot location fetch (Intent-safe)

final class OneShotLocationFetcher: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestCurrentLocation() async -> CLLocation? {
        guard CLLocationManager.locationServicesEnabled() else { return nil }
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            break
        case .restricted, .denied:
            return nil
        case .notDetermined:
            break
        @unknown default:
            break
        }

        return await withCheckedContinuation { (cont: CheckedContinuation<CLLocation?, Never>) in
            continuation = cont
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        continuation?.resume(returning: locations.last)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(returning: nil)
        continuation = nil
    }
}

// MARK: - AppIntent for Quick Log

struct QuickLogIntent: AppIntent {
    static let title: LocalizedStringResource = "Quick Log"
    static let description: IntentDescription = IntentDescription("Log a pee event quickly with selected quality.")
    static var openAppWhenRun: Bool { false }

    @Parameter(title: "Quality")
    var quality: QualityParameter

    init() {}
    init(quality: QualityParameter) { self.quality = quality }

    func perform() async throws -> some IntentResult {
        // Without location: do not attach any lat/lon/name, only quality and timestamp
        let payload: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "quality": quality.rawPeeQuality
        ]
        QuickLogQueue.enqueue(payload: payload)
        return .result()
    }
}

// MARK: - AppIntent: Toggle Live Location Mode

struct QuickLogToggleLocationIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Live Location"
    static let description = IntentDescription("Turn on/off live location logging from the widget.")
    static var openAppWhenRun: Bool { false }

    @Parameter(title: "Enable Live Location")
    var newValue: Bool

    init() {}
    init(newValue: Bool) { self.newValue = newValue }

    func perform() async throws -> some IntentResult {
        QuickLogSettings.writeUseLiveLocation(newValue)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Quality Parameter

enum QualityParameter: String, AppEnum, CaseDisplayRepresentable, Codable, Hashable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Pee Quality"
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .clear: "Clear",
        .paleYellow: "Pale Yellow",
        .yellow: "Yellow",
        .darkYellow: "Dark Yellow",
        .amber: "Amber"
    ]

    case clear
    case paleYellow
    case yellow
    case darkYellow
    case amber

    var rawPeeQuality: String {
        switch self {
        case .clear: return "Clear"
        case .paleYellow: return "Pale Yellow"
        case .yellow: return "Yellow"
        case .darkYellow: return "Dark Yellow"
        case .amber: return "Amber"
        }
    }
}

// MARK: - Widget UI

struct QuickLogProvider: TimelineProvider {
    struct Entry: TimelineEntry {
        let date: Date
        let locationName: String?
        let qualities: [PeeQuality]
        let useLiveLocation: Bool
    }

    func placeholder(in context: Context) -> Entry {
        .init(date: Date(), locationName: "Current Location", qualities: PeeQuality.allCases, useLiveLocation: QuickLogSettings.readUseLiveLocation())
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        let (_, name) = SharedStorage.readLocation()
        completion(.init(date: Date(), locationName: name, qualities: PeeQuality.allCases, useLiveLocation: QuickLogSettings.readUseLiveLocation()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let (_, name) = SharedStorage.readLocation()
        let entry = Entry(date: Date(), locationName: name, qualities: PeeQuality.allCases, useLiveLocation: QuickLogSettings.readUseLiveLocation())
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60 * 10))))
    }
}

private extension PeeQuality {
    var shortLabel: String {
        switch self {
        case .clear: return "Clear"
        case .paleYellow: return "Pale"
        case .yellow: return "Yellow"
        case .darkYellow: return "Dark"
        case .amber: return "Amber"
        }
    }
    // Extra-compact label to ensure no wrap in small widgets
    var abbrevLabel: String {
        switch self {
        case .clear: return "Clr"
        case .paleYellow: return "Pale"
        case .yellow: return "Yel"
        case .darkYellow: return "Dark"
        case .amber: return "Ambr"
        }
    }
    var asParam: QualityParameter {
        switch self {
        case .clear: return .clear
        case .paleYellow: return .paleYellow
        case .yellow: return .yellow
        case .darkYellow: return .darkYellow
        case .amber: return .amber
        }
    }
}

// MARK: - Quality pill button

private enum PillSizeStyle {
    case small, medium, large
}

private struct QualityPillButton: View {
    let quality: PeeQuality
    let size: PillSizeStyle
    let useLiveLocation: Bool

    var body: some View {
        Group {
            if useLiveLocation {
                Link(destination: deepLink) { content }
            } else {
                Button(intent: QuickLogIntent(quality: quality.asParam)) { content }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
            VStack(spacing: size == .small ? 2 : 4) {
                Image(systemName: "drop.fill")
                    .font(size == .small ? .title3 : (size == .medium ? .title3 : .title2))
                    .foregroundStyle(quality.color)
                if size != .small {
                    Text(labelText)
                        .font(size == .medium ? .caption2 : .caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .allowsTightening(true)
                        .foregroundStyle(.primary)
                }
            }
            .padding(size == .small ? 6 : (size == .medium ? 8 : 10))
            .frame(maxWidth: .infinity)
            .background(quality.color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: size == .small ? 10 : 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size == .small ? 10 : 12, style: .continuous)
                    .stroke(quality.color.opacity(0.35), lineWidth: 2)
            )
            .accessibilityLabel(Text(accessibility))
    }

    private var labelText: String {
        switch size {
        case .small: return quality.abbrevLabel
        case .medium, .large: return quality.shortLabel
        }
    }

    private var accessibility: String {
        switch quality {
        case .clear: return "Clear quality"
        case .paleYellow: return "Pale yellow quality"
        case .yellow: return "Yellow quality"
        case .darkYellow: return "Dark yellow quality"
        case .amber: return "Amber quality"
        }
    }

    private var deepLink: URL {
        var comps = URLComponents()
        comps.scheme = "peelog"
        comps.host = "quicklog"
        comps.queryItems = [
            URLQueryItem(name: "quality", value: quality.rawValue)
        ]
        return comps.url ?? URL(string: "peelog://quicklog?quality=\(quality.rawValue)")!
    }
}

struct QuickLogSmallView: View {
    let entry: QuickLogProvider.Entry

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text("Quick Log")
                    .font(.caption)
                Spacer()
                Button(intent: QuickLogToggleLocationIntent(newValue: !entry.useLiveLocation)) {
                    Image(systemName: entry.useLiveLocation ? "location.fill" : "location")
                        .font(.caption)
                        .foregroundStyle(entry.useLiveLocation ? .blue : .secondary)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(entry.useLiveLocation ? Color.blue.opacity(0.12) : Color.secondary.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
            }
            Text(entry.useLiveLocation ? (entry.locationName ?? "Using current location") : "No location")
                .font(.caption2)
                .lineLimit(1)
                .foregroundStyle(.secondary)
            // Two centered rows: 3 items then 2 items, icon-only
            HStack(spacing: 6) {
                ForEach([PeeQuality.clear, .paleYellow, .yellow], id: \.rawValue) { q in
                    QualityPillButton(quality: q, size: .small, useLiveLocation: entry.useLiveLocation)
                }
            }
            HStack(spacing: 6) {
                Spacer(minLength: 0)
                ForEach([PeeQuality.darkYellow, .amber], id: \.rawValue) { q in
                    QualityPillButton(quality: q, size: .small, useLiveLocation: entry.useLiveLocation)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(8)
    }
}

struct QuickLogMediumView: View {
    let entry: QuickLogProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Quick Log")
                    .font(.headline)
                Spacer()
                Button(intent: QuickLogToggleLocationIntent(newValue: !entry.useLiveLocation)) {
                    HStack(spacing: 4) {
                        Image(systemName: entry.useLiveLocation ? "location.fill" : "location")
                        Text(entry.useLiveLocation ? "With Loc" : "No Loc")
                            .font(.caption2)
                    }
                    .foregroundStyle(entry.useLiveLocation ? .blue : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(entry.useLiveLocation ? Color.blue.opacity(0.12) : Color.secondary.opacity(0.12))
                    )
                }
                .buttonStyle(.plain)
            }
            Text(entry.useLiveLocation ? (entry.locationName ?? "Using current location") : "No location")
                .font(.caption)
                .foregroundStyle(.secondary)
            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(entry.qualities, id: \.rawValue) { q in
                    QualityPillButton(quality: q, size: .medium, useLiveLocation: entry.useLiveLocation)
                }
            }
        }
        .padding(12)
    }
}

struct QuickLogLargeView: View {
    let entry: QuickLogProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Quick Log")
                        .font(.title3)
                    Text(entry.locationName ?? "Using current location")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(intent: QuickLogToggleLocationIntent(newValue: !entry.useLiveLocation)) {
                    HStack(spacing: 6) {
                        Image(systemName: entry.useLiveLocation ? "location.fill" : "location")
                        Text(entry.useLiveLocation ? "With Loc" : "No Loc")
                            .font(.caption2)
                    }
                    .foregroundStyle(entry.useLiveLocation ? .blue : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(entry.useLiveLocation ? Color.blue.opacity(0.12) : Color.secondary.opacity(0.12))
                    )
                }
                .buttonStyle(.plain)
            }
            let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(entry.qualities, id: \.rawValue) { q in
                    QualityPillButton(quality: q, size: .large, useLiveLocation: entry.useLiveLocation)
                }
            }
        }
        .padding(16)
    }
}

struct QuickLogWidgetEntryView : View {
    var entry: QuickLogProvider.Entry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            QuickLogSmallView(entry: entry)
        case .systemMedium:
            QuickLogMediumView(entry: entry)
        case .systemLarge:
            QuickLogLargeView(entry: entry)
        default:
            QuickLogMediumView(entry: entry)
        }
    }
}

struct QuickLogWidget: Widget {
    let kind: String = "QuickLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickLogProvider()) { entry in
            QuickLogWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [.blue.opacity(0.18), .purple.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
        }
        .configurationDisplayName("Quick Log")
        .description("Log quickly from your Home Screen")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}


#if DEBUG
struct QuickLogWidget_Previews: PreviewProvider {
    static var entry: QuickLogProvider.Entry = .init(
        date: Date(),
        locationName: "Current Location",
        qualities: PeeQuality.allCases,
        useLiveLocation: true
    )

    static var previews: some View {
        Group {
            QuickLogWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { LinearGradient(colors: [.blue.opacity(0.18), .purple.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing) }
                .previewContext(WidgetPreviewContext(family: .systemSmall))

            QuickLogWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { LinearGradient(colors: [.blue.opacity(0.18), .purple.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing) }
                .previewContext(WidgetPreviewContext(family: .systemMedium))

            QuickLogWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) { LinearGradient(colors: [.blue.opacity(0.18), .purple.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing) }
                .previewContext(WidgetPreviewContext(family: .systemLarge))
        }
    }
}
#endif



