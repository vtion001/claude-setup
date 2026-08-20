# Pass 02 — Swift Testing Adoption

**Weight:** 1×

## What this audits
Is the project using the modern Swift Testing framework (Xcode 16+ /
`@Test` macro) for new unit tests, while retaining XCTest for UI + perf?

## Tier 0
```bash
grep -rln --include='*.swift' '@Test\|@Suite\|import Testing' <project-root>
grep -rln --include='*.swift' 'class.*: XCTestCase' <project-root>
```

## Scoring
| Score | Criteria |
|---|---|
| 5 | New unit tests use Swift Testing; XCTest only for UI + perf |
| 4 | Recent migrations to Swift Testing; mixed |
| 3 | All XCTest; no Swift Testing adoption yet |
| 2 | Mixing styles confusingly within the same file |
| 1 | N/A (Swift Testing is opt-in) |

## Common findings
| Finding | Severity |
|---|---|
| New tests still using XCTest | **Low** |
| `@Test` and `func test*` mixed unclearly | **Medium** |
| Swift Testing assertions written like XCTAssert (missing parameterized power) | **Low** |

## Recommended fix
For new files, use `@Test`. Existing XCTest stays.

```swift
import Testing

@Suite("LocalAIService")
struct LocalAIServiceTests {
    @Test("Returns response on valid input")
    func validInput() async throws {
        let service = LocalAIService.shared
        let result = try await service.respond(to: "hi")
        #expect(!result.isEmpty)
    }
}
```

## What NOT to flag
- iOS 16- targets that can't use Swift Testing
- UI tests staying on XCTest (correct decision)
