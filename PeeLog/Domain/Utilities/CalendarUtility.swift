//
//  CalendarUtility.swift
//  PeeLog
//
//  Created by Arrinal S on 25/06/25.
//

import Foundation

// MARK: - Calendar Utility
struct CalendarUtility {
    
    // MARK: - Shared Calendar Instance
    
    /// Returns the current calendar instance
    static var current: Calendar {
        return Calendar.current
    }
    
    // MARK: - Date Calculations
    
    /// Returns the start of day for a given date
    static func startOfDay(for date: Date) -> Date {
        return current.startOfDay(for: date)
    }
    
    /// Returns the end of day for a given date
    static func endOfDay(for date: Date) -> Date {
        return current.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date
    }
    
    /// Returns a date by adding components to a given date
    static func date(byAdding component: Calendar.Component, value: Int, to date: Date) -> Date? {
        return current.date(byAdding: component, value: value, to: date)
    }
    
    /// Returns a date by adding days to a given date
    static func date(byAddingDays days: Int, to date: Date) -> Date? {
        return current.date(byAdding: .day, value: days, to: date)
    }
    
    /// Returns a date by adding months to a given date
    static func date(byAddingMonths months: Int, to date: Date) -> Date? {
        return current.date(byAdding: .month, value: months, to: date)
    }
    
    /// Returns a date by adding years to a given date
    static func date(byAddingYears years: Int, to date: Date) -> Date? {
        return current.date(byAdding: .year, value: years, to: date)
    }
    
    // MARK: - Date Components
    
    /// Returns the hour component of a given date
    static func hour(from date: Date) -> Int {
        return current.component(.hour, from: date)
    }
    
    /// Returns the day component of a given date
    static func day(from date: Date) -> Int {
        return current.component(.day, from: date)
    }
    
    /// Returns the month component of a given date
    static func month(from date: Date) -> Int {
        return current.component(.month, from: date)
    }
    
    /// Returns the year component of a given date
    static func year(from date: Date) -> Int {
        return current.component(.year, from: date)
    }
    
    // MARK: - Date Comparisons
    
    /// Checks if a date is in today
    static func isDateInToday(_ date: Date) -> Bool {
        return current.isDateInToday(date)
    }
    
    /// Checks if two dates are in the same day
    static func isDate(_ date1: Date, inSameDayAs date2: Date) -> Bool {
        return current.isDate(date1, inSameDayAs: date2)
    }
    
    // MARK: - Common Date Calculations
    
    /// Returns the date for N days ago from now
    static func daysAgo(_ days: Int) -> Date {
        return date(byAddingDays: -days, to: Date()) ?? Date()
    }
    
    /// Returns the date for N months ago from now
    static func monthsAgo(_ months: Int) -> Date {
        return date(byAddingMonths: -months, to: Date()) ?? Date()
    }
    
    /// Returns the date for N years ago from now
    static func yearsAgo(_ years: Int) -> Date {
        return date(byAddingYears: -years, to: Date()) ?? Date()
    }
    
    // MARK: - Week Calculations
    
    /// Returns the start of the week for a given date
    static func startOfWeek(for date: Date) -> Date {
        let calendar = current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }
    
    /// Returns the end of the week for a given date
    static func endOfWeek(for date: Date) -> Date {
        let startOfWeek = startOfWeek(for: date)
        return CalendarUtility.date(byAddingDays: 6, to: startOfWeek) ?? date
    }
    
    /// Returns the date for the beginning of the week N weeks ago
    static func weeksAgo(_ weeks: Int) -> Date {
        return date(byAdding: .weekOfYear, value: -weeks, to: Date()) ?? Date()
    }
    
    // MARK: - Grouping Helpers
    
    /// Groups events by day
    static func groupEventsByDay<T>(_ events: [T], dateKeyPath: KeyPath<T, Date>) -> [Date: [T]] {
        return Dictionary(grouping: events) { event in
            startOfDay(for: event[keyPath: dateKeyPath])
        }
    }
    
    /// Groups events by hour
    static func groupEventsByHour<T>(_ events: [T], dateKeyPath: KeyPath<T, Date>) -> [Int: [T]] {
        return Dictionary(grouping: events) { event in
            hour(from: event[keyPath: dateKeyPath])
        }
    }
    
    /// Groups events by month
    static func groupEventsByMonth<T>(_ events: [T], dateKeyPath: KeyPath<T, Date>) -> [Int: [T]] {
        return Dictionary(grouping: events) { event in
            month(from: event[keyPath: dateKeyPath])
        }
    }
} 