import Foundation

// Minimal, dependency-free test runner. XCTest is not shipped with the
// Command Line Tools and SwiftPM is not required to build ScrollFlip,
// so the tests are a plain executable compiled together with Sources/Core.

enum TestRun {
    static var passed = 0
    static var failed = 0
    static var currentFailed = false
    static var currentName = ""
}

func suite(_ name: String, _ body: () -> Void) {
    print("\n\(name)")
    body()
}

func test(_ name: String, _ body: () throws -> Void) {
    TestRun.currentName = name
    TestRun.currentFailed = false
    do {
        try body()
    } catch {
        fail("threw \(error)")
    }
    if TestRun.currentFailed {
        TestRun.failed += 1
    } else {
        TestRun.passed += 1
        print("  ✔ \(name)")
    }
}

func fail(_ message: String, file: StaticString = #fileID, line: UInt = #line) {
    if !TestRun.currentFailed { print("  ✘ \(TestRun.currentName)") }
    TestRun.currentFailed = true
    print("      \(message)  [\(file):\(line)]")
}

func expect(_ condition: @autoclosure () -> Bool, _ message: @autoclosure () -> String = "expectation failed",
            file: StaticString = #fileID, line: UInt = #line) {
    if !condition() { fail(message(), file: file, line: line) }
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ label: String = "",
                               file: StaticString = #fileID, line: UInt = #line) {
    if actual != expected {
        fail("\(label.isEmpty ? "" : label + ": ")expected \(expected), got \(actual)", file: file, line: line)
    }
}
