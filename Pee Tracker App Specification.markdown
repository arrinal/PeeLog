# Pee Tracker App Specification

## Overview
Build an iOS app called "Pee Tracker" using SwiftUI, Swift 6, and SwiftData for local storage. The app tracks urination events with a simple, user-friendly interface.

## Requirements
- **Platform**: iOS
- **Language**: Swift 6
- **Framework**: SwiftUI
- **Storage**: SwiftData (local storage, no user accounts)

## Data Model
Define a `PeeEvent` model:
```swift
@Model
class PeeEvent {
    var id: UUID
    var timestamp: Date
    var notes: String?

    init(timestamp: Date, notes: String? = nil) {
        self.id = UUID()
        self.timestamp = timestamp
        self.notes = notes
    }
}
```

## App Structure
Set up the main app file to use the SwiftData model container:
```swift
import SwiftUI
import SwiftData

@main
struct PeeTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: PeeEvent.self)
    }
}
```

## Screens and Functionality

### 1. Dashboard (ContentView)
- **Purpose**: Display today’s pee events and allow logging new ones.
- **UI**:
  - Navigation title: "Pee Tracker".
  - List with one section titled "Today".
  - Section header: `Text("Pee events: \(todaysEvents.count)")`.
  - List items: For each event today, show `Text(event.timestamp, style: .time)` and, if notes exist, `Text(notes)`.
  - Swipe to delete events.
  - Toolbar:
    - Trailing: Button with `Image(systemName: "plus")` to show `AddEventView` as a sheet.
    - Leading: `NavigationLink` to `HistoryView` with `Image(systemName: "calendar")`.
- **Logic**:
  - Use `@Query(sort: \PeeEvent.timestamp, order: .reverse)` to fetch all events.
  - Filter for today: `peeEvents.filter { Calendar.current.isDateInToday($0.timestamp) }`.
  - Use `@Environment(\.modelContext)` for deleting events.

### 2. AddEventView (Sheet)
- **Purpose**: Log a new pee event.
- **UI**:
  - Form with:
    - `DatePicker("Time", selection: $timestamp, displayedComponents: .dateAndTime)` (default: `Date()`).
    - `TextField("Notes", text: $notes)` (optional).
  - Navigation title: "Log Pee Event".
  - Toolbar:
    - Trailing: "Save" button to insert the event and dismiss.
    - Leading: "Cancel" button to dismiss without saving.
- **Logic**:
  - Use `@Environment(\.modelContext)` to insert a new `PeeEvent`.
  - Use `@Environment(\.dismiss)` to close the sheet.

### 3. HistoryView
- **Purpose**: Show all past pee events.
- **UI**:
  - List with sections grouped by date.
  - Section header: `Text(date, style: .date)`.
  - List items: For each event, show `Text(event.timestamp, style: .time)` and, if notes exist, `Text(notes)`.
  - Navigation title: "History".
- **Logic**:
  - Use `@Query(sort: \PeeEvent.timestamp, order: .reverse)` to fetch all events.
  - Group by day: `Dictionary(grouping: peeEvents) { Calendar.current.startOfDay(for: $0.timestamp) }`.

## Implementation Steps
1. Create a new SwiftUI project in Xcode with Swift 6.
2. Define the `PeeEvent` model as shown.
3. Configure the main app with the SwiftData container.
4. Implement `ContentView` with the Dashboard UI and logic.
5. Implement `AddEventView` as a sheet for logging events.
6. Implement `HistoryView` for past events.
7. Test adding, viewing, and deleting events to ensure functionality.

## UI/UX Guidelines
- Use standard SwiftUI components (e.g., `List`, `Section`, `Form`).
- Apply a calming blue color scheme (e.g., `.blue.opacity(0.1)` for backgrounds).
- Add a water droplet icon (`Image(systemName: "drop.fill")`) next to each event for visual appeal.
- Ensure fast, responsive performance.

## Notes
- Focus on core functionality for this version.
- Future enhancements could include reminders, data export, or charts.


User Interface (UI)
The UI should be clean, intuitive, and focused on ease of use, given its purpose of tracking urination events. A water-themed design with calming blue tones can tie into the app’s focus on bodily fluids. Here’s the breakdown:

Main Screen (Dashboard):
A list of today’s pee events (time and optional notes), with the newest at the top.
A header showing today’s pee count (e.g., "Pee events today: 3").
A prominent "+" button to log a new event.
A navigation bar with a calendar icon to view history.
Log Entry Screen:
A simple form, presented as a sheet over the Dashboard.
Fields: timestamp (defaulting to now, editable), optional notes.
Buttons: "Save" to log the event, "Cancel" to dismiss.
History Screen:
A list of all pee events, grouped by date (e.g., sections for each day).
Each entry shows the time and notes (if provided).
Number of Screens
The app will have three screens:

Dashboard: The main view for today’s tracking and logging.
Log Entry: A modal sheet for adding new events.
History: A separate view for past events.
This keeps the app minimal yet functional, ideal for a first version.

Making It Engaging
To keep users interested:

Visual Feedback: Use subtle animations (e.g., a ripple effect) when logging an event, and a water droplet icon next to each entry.
Progress Insight: Show a daily summary on the Dashboard (e.g., "3 pees today") to give users a sense of accomplishment.
Simplicity: A fast, responsive UI with a calming blue theme ensures a pleasant experience, encouraging regular use.
Future enhancements could include gamification (e.g., streaks) or charts, but for now, simplicity and usability are key.

Essential Features
For a basic, functional version:

Log Pee Events: Quickly record an event with a timestamp and optional notes.
View Today’s Activity: See all pee events for the current day on the Dashboard.
View History: Access a full log of past events, grouped by date.
Delete Events: Swipe to remove incorrect entries from the Dashboard.
Additional features like reminders or data export can be added later.