func localizationTests() {
    test("every string exists in Spanish and English") {
        for key in L.allCases {
            let es = key.text(.spanish)
            let en = key.text(.english)
            expect(!es.trimmingCharacters(in: .whitespaces).isEmpty, "\(key): empty Spanish text")
            expect(!en.trimmingCharacters(in: .whitespaces).isEmpty, "\(key): empty English text")
        }
    }

    test("'system' always resolves to a concrete language") {
        expect(Language.system.resolved != .system)
        expectEqual(Language.spanish.resolved, .spanish)
        expectEqual(Language.english.resolved, .english)
    }

    test("language raw values are stable (they are persisted)") {
        expectEqual(Language.system.rawValue, "system")
        expectEqual(Language.spanish.rawValue, "es")
        expectEqual(Language.english.rawValue, "en")
    }
}
