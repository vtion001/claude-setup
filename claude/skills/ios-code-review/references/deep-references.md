# /ios-code-review — Deep References

## Canonical sources

- **Swift API Design Guidelines** — https://www.swift.org/documentation/api-design-guidelines/
  The foundational document. Every API-design pass cites a section.
- **Swift Forums / Evolution** — https://forums.swift.org/c/evolution/18
  Proposals (SE-XXXX) drive idiom adoption. Track recent accepted ones.
- **Apple's Swift Book** — https://docs.swift.org/swift-book/
  Authoritative language reference.

## Style enforcement tooling

- **SwiftLint rule index** — https://realm.github.io/SwiftLint/rule-directory.html
- **SwiftFormat options** — https://github.com/nicklockwood/SwiftFormat#rules
- **Periphery README** — https://github.com/peripheryapp/periphery

## Public sample configs (start here, then customize)

- **Airbnb Swift Style Guide** — https://github.com/airbnb/swift
- **raywenderlich / Kodeco Swift Style Guide** — https://github.com/kodecocodes/swift-style-guide
- **Google Swift Style Guide** — https://google.github.io/swift/
- **Realm Cocoa SwiftLint config** — https://github.com/realm/realm-swift/blob/master/.swiftlint.yml

## Dead-code policy

- **MobileNativeFoundation consensus** (Lyft / Spotify / Airbnb / Reddit
  agreed approach): https://github.com/MobileNativeFoundation/discussions/discussions/156
- **Periphery 3.0 release notes**:
  https://medium.com/swiftfy/clean-your-dead-code-with-periphery-3-0-on-ios-dc6031aa50eb

## SwiftUI-specific style references

- **Swift Style** (Vincent Pradeilles): https://www.swiftbysundell.com/
- **Swift by Sundell** weekly newsletter
- **Point-Free** — patterns library: https://www.pointfree.co/

## Swift evolution (recent + relevant)

- **SE-0413 — Typed throws** (Swift 6)
- **SE-0395 — Observation** (`@Observable` macro, Swift 5.9+)
- **SE-0411 — Isolated default-value expressions**
- **SE-0420 — Inheritance of actor isolation**

When recommending modernization, cite the SE-XXXX.

## Documentation comment style

- **Apple's DocC** — https://www.swift.org/documentation/docc/
- **Swift documentation markup spec** — https://github.com/apple/swift/blob/main/docs/DocumentationComments.md
