import Foundation
import FolioCore

func runAppearanceTests() {
    T.test("Appearance rawValues match the UserDefaults persistence contract") {
        // These string values are written to UserDefaults under Folio.appearance.
        // Changing them is a migration-breaking change.
        T.equal(Appearance.system.rawValue, "system")
        T.equal(Appearance.light.rawValue, "light")
        T.equal(Appearance.dark.rawValue, "dark")
    }

    T.test("cssBodyClass maps each appearance to a distinct, stable class name") {
        T.equal(Appearance.system.cssBodyClass, "theme-system")
        T.equal(Appearance.light.cssBodyClass, "theme-light")
        T.equal(Appearance.dark.cssBodyClass, "theme-dark")
    }

    T.test("displayName is human-readable for the Settings picker") {
        T.equal(Appearance.system.displayName, "System")
        T.equal(Appearance.light.displayName, "Light")
        T.equal(Appearance.dark.displayName, "Dark")
    }

    T.test("allCases enumerates exactly the three expected appearances") {
        // Order matters for the Settings segmented picker.
        T.equal(Appearance.allCases, [.system, .light, .dark])
    }

    T.test("PreviewHTML.document stamps body with the requested theme class") {
        let dark = PreviewHTML.document(title: "x", body: "<p>y</p>", theme: .dark)
        T.contains(dark, "<body class=\"theme-dark\">")

        let light = PreviewHTML.document(title: "x", body: "<p>y</p>", theme: .light)
        T.contains(light, "<body class=\"theme-light\">")

        let system = PreviewHTML.document(title: "x", body: "<p>y</p>", theme: .system)
        T.contains(system, "<body class=\"theme-system\">")
    }

    T.test("PreviewHTML.document defaults to system theme when omitted") {
        // Existing callers that don't pass `theme:` should get the system-following class,
        // so a preview rendered without a user preference still tracks macOS dark mode.
        let doc = PreviewHTML.document(title: "x", body: "<p>y</p>")
        T.contains(doc, "<body class=\"theme-system\">")
    }

    T.test("CSS stylesheet defines theme-specific palette overrides") {
        // Sanity-check that the stylesheet contains the class-keyed selectors used by
        // the body-class theme switching. Without these, an explicit Dark choice
        // would still render with the default (light) palette.
        T.contains(Styles.css, "body.theme-dark")
        T.contains(Styles.css, "body.theme-system")
    }
}
