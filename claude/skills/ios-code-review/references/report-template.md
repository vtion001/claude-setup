# /ios-code-review — Report Template

Extends `_ios-shared/report-template-shared.md`. Adds code-review-specific
sections.

## Additional sections

### Lint Summary
```
SwiftLint: <X> violations (E:<n> W:<m>)
SwiftFormat: <Y> file diffs
Periphery: <Z> unused symbols
```

### Top 10 noisy rules
Sorted by violation count; shows which rules generate the most noise (and
might be miscalibrated).

### Architecture observations
1-3 paragraphs on file/folder structure, module boundaries, and dependency
direction. Not a finding list — a higher-level view.

### Modernization opportunities
List of Swift evolution proposals (SE-XXXX) the codebase hasn't adopted
yet, ordered by impact-to-effort. References the proposal URL.
