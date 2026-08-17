// a11y-audit-runner.swift — XCUITest template for Pass 09.
//
// Drop into the project's UI-test target (created by --bootstrap or added
// manually). The skill invokes this test via:
//
//   xcodebuild test \
//     -scheme <scheme> \
//     -destination 'platform=iOS Simulator,id=<UDID>' \
//     -only-testing:<UITestTargetName>/A11yAuditTests/testFullAuditAllTabs \
//     AUDIT_TABS="home,flights,tips,assistant,settings" \
//     AUDIT_OUTPUT_PATH=/<project>/swiftui-ux-audit/.xcui-a11y.json
//
// Requires iOS 17+ deployment target (XCUIApplication.performAccessibilityAudit
// was added in iOS 17 / Xcode 15).

import XCTest

final class A11yAuditTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    @available(iOS 17.0, *)
    func testFullAuditAllTabs() throws {
        let app = XCUIApplication()
        app.launch()

        let tabsEnv = ProcessInfo.processInfo.environment["AUDIT_TABS"] ?? ""
        let tabs = tabsEnv
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var aggregated: [[String: Any]] = []

        // Always include the launch screen as the first "tab" so empty-tab
        // projects still produce useful output.
        let tabList: [String] = tabs.isEmpty ? ["__launch__"] : tabs

        for tab in tabList {
            if tab != "__launch__" {
                // Navigate by visible label first; fall back to a11y identifier.
                let byLabel = app.buttons[tab.capitalized].firstMatch
                let byId    = app.buttons[tab].firstMatch
                if byLabel.exists { byLabel.tap() }
                else if byId.exists { byId.tap() }
                // give SwiftUI a beat
                _ = app.wait(for: .runningForeground, timeout: 1)
                usleep(400_000)
            }

            do {
                try app.performAccessibilityAudit(for: .all) { issue in
                    let typeString = String(describing: issue.auditType)
                    let desc = issue.compactDescription ?? "<no description>"
                    let elementDesc: String
                    if let el = issue.element {
                        elementDesc = el.debugDescription
                    } else {
                        elementDesc = "nil"
                    }
                    aggregated.append([
                        "tab": tab,
                        "type": typeString,
                        "description": desc,
                        "element": elementDesc
                    ])
                    return true   // continue collecting, never fail-fast
                }
            } catch {
                aggregated.append([
                    "tab": tab,
                    "type": "audit_error",
                    "description": "\(error)",
                    "element": "n/a"
                ])
            }
        }

        // Write out as JSON.
        let outPath = ProcessInfo.processInfo.environment["AUDIT_OUTPUT_PATH"]
            ?? NSTemporaryDirectory() + "swiftui-ux-audit-a11y.json"
        let outURL = URL(fileURLWithPath: outPath)
        try FileManager.default.createDirectory(
            at: outURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONSerialization.data(
            withJSONObject: aggregated,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: outURL)

        // Always pass the test; the skill consumes the JSON externally.
        XCTAssertTrue(true)
    }
}
