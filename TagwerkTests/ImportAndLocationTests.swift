import Foundation
import CoreLocation
import Testing
@testable import Tagwerk

@Suite("Import aus Text")
struct TextLineImportTests {
    @Test func checklistLinesWithTags() {
        let text = """
        - [ ] Milch kaufen #einkauf
        - [x] Schon erledigt
        1. Steuer machen #finanzen #wichtig

        • Zahnarzt anrufen
        """
        let tasks = TextImport.parse(text, fileExtension: "txt")
        #expect(tasks.map(\.title) == ["Milch kaufen", "Steuer machen", "Zahnarzt anrufen"])
        #expect(tasks[0].tags == ["einkauf"])
        #expect(tasks[1].tags == ["finanzen", "wichtig"])
    }
}

@Suite("Import aus CSV")
struct CSVImportTests {
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    @Test func todoistStyleCSV() {
        let csv = """
        Title,Priority,Due Date,Project,Status
        "Bericht, Teil 2",p1,2026-11-20,Arbeit,
        Brot,,,Einkauf;Zuhause,
        Alt,,,,completed
        """
        let tasks = TextImport.parse(csv, fileExtension: "csv", calendar: calendar)
        #expect(tasks.count == 2)
        #expect(tasks[0].title == "Bericht, Teil 2")
        #expect(tasks[0].priority == .high)
        #expect(tasks[0].tags == ["Arbeit"])
        let expected = calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 9))
        #expect(tasks[0].due == expected)
        #expect(tasks[1].tags == ["Einkauf", "Zuhause"])
    }

    @Test func germanSemicolonCSV() {
        let csv = "Titel;Fällig;Liste\nArzttermin;21.11.2026 14:30;Gesundheit"
        let tasks = TextImport.parse(csv, fileExtension: "csv", calendar: calendar)
        let expected = calendar.date(from: DateComponents(year: 2026, month: 11, day: 21, hour: 14, minute: 30))
        #expect(tasks == [ImportedTask(title: "Arzttermin", due: expected, tags: ["Gesundheit"])])
    }

    @Test func quotedFieldsWithEscapedQuotes() {
        #expect(TextImport.splitCSVLine("a,\"b \"\"c\"\", d\",e", separator: ",") == ["a", "b \"c\", d", "e"])
    }
}

@Suite("Import aus .ics")
struct ICSImportTests {
    @Test func vtodoEntries() {
        let ics = """
        BEGIN:VCALENDAR\r
        BEGIN:VTODO\r
        SUMMARY:Präsentation vorbereiten\r
        DUE:20261120T080000Z\r
        PRIORITY:1\r
        CATEGORIES:Arbeit,Kunde\r
        DESCRIPTION:Folien\\, Zahlen\r
        END:VTODO\r
        BEGIN:VTODO\r
        SUMMARY:Erledigt\r
        STATUS:COMPLETED\r
        END:VTODO\r
        END:VCALENDAR\r
        """
        let tasks = TextImport.parse(ics, fileExtension: "ics")
        #expect(tasks.count == 1)
        #expect(tasks[0].title == "Präsentation vorbereiten")
        #expect(tasks[0].priority == .high)
        #expect(tasks[0].tags == ["Arbeit", "Kunde"])
        #expect(tasks[0].notes == "Folien, Zahlen")
        #expect(tasks[0].due == Date(timeIntervalSince1970: 1_795_161_600))
    }
}

@Suite("Übersetzung anderer Apps")
struct ImportMappingTests {
    @Test func priorities() {
        #expect(ImportMapping.priority(fromICalendar: 1) == .high)
        #expect(ImportMapping.priority(fromICalendar: 5) == .medium)
        #expect(ImportMapping.priority(fromICalendar: 9) == .low)
        #expect(ImportMapping.priority(fromICalendar: 0) == .none)
    }

    @Test func recurrences() {
        #expect(ImportMapping.recurrence(frequency: .weekly, interval: 2) == .biweekly)
        #expect(ImportMapping.recurrence(frequency: .monthly, interval: 1) == .monthly)
        #expect(ImportMapping.recurrence(frequency: .monthly, interval: 3) == .none)
    }
}

@Suite("Orts-Tags")
struct LocationMatchTests {
    let office = (latitude: 50.0000, longitude: 8.2700)

    @Test func insideRadius() {
        let nearby = CLLocation(latitude: 50.0009, longitude: 8.2700) // ca. 100 m nördlich
        #expect(LocationMatch.isNear(latitude: office.latitude, longitude: office.longitude, radius: 150, to: nearby))
    }

    @Test func outsideRadius() {
        let far = CLLocation(latitude: 50.0030, longitude: 8.2700) // ca. 330 m
        #expect(!LocationMatch.isNear(latitude: office.latitude, longitude: office.longitude, radius: 150, to: far))
    }

    @Test func noLocationNoMatch() {
        #expect(!LocationMatch.isNear(latitude: nil, longitude: 8.27, radius: 150, to: CLLocation(latitude: 50, longitude: 8.27)))
        #expect(!LocationMatch.isNear(latitude: 50, longitude: 8.27, radius: 150, to: nil))
    }
}
