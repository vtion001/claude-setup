# Pass 06 — Request Cancellation

**Weight:** 2×

## What this audits
When a screen leaves or a search query changes, are in-flight requests
canceled? Otherwise: memory bloat + battery + completion handlers firing
on stale state.

## Tier 0
```bash
grep -rln --include='*.swift' 'Task.cancel\|task.cancel\|URLSessionTask.cancel\|withTaskCancellationHandler' <project-root>
```

## Scoring
| Score | Criteria |
|---|---|
| 5 | All long-running views/queries cancel on disappear / new input |
| 4 | Most cancel; 1-2 places where they don't |
| 3 | Some awareness; cancellation logic patchy |
| 2 | No cancellation; tasks accumulate |
| 1 | Active task leakage causing crashes or wrong-data renders |

## Recommended fix
```swift
struct SearchView: View {
    @State private var searchTask: Task<Void, Never>?
    var body: some View {
        TextField("Search", text: $query)
            .onChange(of: query) { _, new in
                searchTask?.cancel()
                searchTask = Task { await fetch(new) }
            }
            .onDisappear { searchTask?.cancel() }
    }
}
```

## What NOT to flag
- Fire-and-forget background sync (cancellation may be unwanted)
- Tasks that already use `.task(id:)` modifier (auto-cancellation)
