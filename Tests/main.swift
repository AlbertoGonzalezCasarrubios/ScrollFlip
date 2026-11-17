import Foundation

print("ScrollFlip tests")

suite("ScrollInverter", scrollInverterTests)
suite("SideButtons", sideButtonTests)
suite("AutoScroll", autoScrollTests)
suite("AppState", appStateTests)
suite("Localization", localizationTests)

print("\n\(TestRun.passed) passed, \(TestRun.failed) failed")
exit(TestRun.failed == 0 ? 0 : 1)
