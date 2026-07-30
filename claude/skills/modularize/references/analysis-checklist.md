# God File Detection Heuristics

Language-specific rules for identifying files that need modularization.

## TypeScript / JavaScript

### Quantitative Signals

```bash
# Count named exports per file
grep -c "^export " <file>
grep -c "^export default" <file>

# Count top-level function declarations
grep -c "^export function\|^export async function\|^export const .* = (" <file>

# Count classes
grep -c "^export class\|^class " <file>

# Line count
wc -l <file>
```

### Qualitative Signals

| Signal | How to Detect | Severity |
|--------|--------------|----------|
| Mixed UI + API | File imports both React/Vue AND fetch/axios/prisma | HIGH |
| Mixed UI + business logic | Component file with >50 lines of non-render logic | MEDIUM |
| Route + handler logic | Express/Next route file with business logic inline | MEDIUM |
| Multiple unrelated exports | Exports with no shared types or imports between them | HIGH |
| Type + implementation mixing | Types/interfaces AND their implementations in same file | LOW |
| Config + runtime mixing | Constants/config AND functions using them in same file | LOW |

### Dump-Drawer Detection

Flag files matching these patterns — they almost always need splitting:

```
**/helpers.ts       **/helpers.js
**/utils.ts         **/utils.js
**/common.ts        **/common.js
**/misc.ts          **/misc.js
**/shared.ts        **/shared.js
**/functions.ts     **/functions.js
**/tools.ts         **/tools.js
```

### Import Depth Analysis

```bash
# Find files with deep relative imports (indicates poor module organization)
grep -r "from '\.\./\.\./\.\." src/ --include="*.ts" --include="*.tsx"
```

Files with 3+ levels of `../` are candidates for reorganization into domain folders.

## Python

### Quantitative Signals

```bash
# Count module-level function definitions
grep -c "^def \|^async def " <file>

# Count class definitions
grep -c "^class " <file>

# Count __all__ entries (explicit exports)
grep "__all__" <file>
```

### Qualitative Signals

| Signal | How to Detect | Severity |
|--------|--------------|----------|
| Mixed ORM + business logic | File imports both SQLAlchemy/Django models AND external APIs | HIGH |
| Mixed routes + logic | Flask/FastAPI route file with >20 lines per route handler | MEDIUM |
| Multiple unrelated classes | Classes with no inheritance/composition relationship | HIGH |
| Utility dump drawer | `utils.py` or `helpers.py` with >10 functions | HIGH |
| Mixed sync + async | Both `def` and `async def` doing unrelated things | LOW |

### Dump-Drawer Detection

```
**/utils.py
**/helpers.py
**/common.py
**/misc.py
**/tools.py
**/functions.py
```

### Python-Specific Considerations

- `__init__.py` files: These are barrel files. Don't split them — update their imports when moving code
- Circular imports in Python: Often fixable by moving imports inside functions (lazy imports)
- Type stubs (`.pyi`): Must be updated when moving the implementation file

## General (All Languages)

### File Size Thresholds

| Category | Lines | Action |
|----------|-------|--------|
| Healthy | <150 | No action needed |
| Watch | 150-300 | Review if >5 exports |
| Split candidate | 300-600 | Likely needs splitting |
| God file | >600 | Definitely needs splitting |

### Responsibility Grouping Strategy

When analyzing a god file, group its exports by:

1. **Shared imports** — functions that import the same dependencies likely belong together
2. **Shared types** — functions operating on the same types/interfaces belong together
3. **Call graph** — functions that call each other belong together
4. **Domain** — functions about the same business concept belong in the same domain folder

### What NOT to Flag

- Framework convention files (`_app.tsx`, `middleware.ts`, `layout.tsx`, `__init__.py`, `conftest.py`)
- Configuration files (`next.config.js`, `tailwind.config.ts`, `pyproject.toml`)
- Migration files (database migrations are supposed to be long single files)
- Generated files (GraphQL codegen, Prisma client, protobuf output)
- Test files (a test file testing one module can be long — that's fine)
