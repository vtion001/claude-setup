# Circular Dependency Detection & Resolution

## Detection Tools

### TypeScript / JavaScript

```bash
# madge — most popular, works with TS
npx madge --circular --extensions ts,tsx src/
npx madge --circular --extensions js,jsx src/

# madge with image output (requires Graphviz)
npx madge --circular --image circular.svg src/

# dpdm — alternative, faster on large codebases
npx dpdm --circular src/index.ts

# eslint plugin (preventative)
# Add to .eslintrc: "import/no-cycle": "error"
```

### Python

```bash
# pydeps
python -m pydeps --no-output --show-cycles src/

# importlab (Google's tool)
pip install importlab
importlab src/

# Manual grep approach
# Find A->B->A patterns by scanning import statements
```

### Manual Detection (Any Language)

```bash
# For each file being split, check if the new location would create a cycle:
# 1. List what the extracted function imports
# 2. List what imports the extracted function
# 3. If any file appears in BOTH lists, you have a potential cycle
```

## Common Circular Dependency Patterns

### Pattern 1: Shared Types

```
# BEFORE (circular):
# user.ts imports from order.ts (needs OrderType)
# order.ts imports from user.ts (needs UserType)

# FIX: Extract shared types to a separate file
# types/shared.ts ← UserType, OrderType
# user.ts imports from types/shared.ts
# order.ts imports from types/shared.ts
```

**Resolution:** Extract shared types/interfaces into a `types/` or `contracts/` directory. Neither module depends on the other — both depend on the shared types.

### Pattern 2: Utility Dependency

```
# BEFORE (circular):
# auth.ts imports from user.ts (needs getCurrentUser)
# user.ts imports from auth.ts (needs isAuthenticated)

# FIX: Extract the shared utility to its own module
# session.ts ← getCurrentUser (uses auth context)
# auth.ts ← isAuthenticated (pure function)
# user.ts imports from session.ts and auth.ts
```

**Resolution:** Find the function that has fewer dependents and extract it to break the cycle.

### Pattern 3: Dependency Inversion

```
# BEFORE (circular):
# service.ts imports from repository.ts (needs Repository)
# repository.ts imports from service.ts (needs ServiceConfig)

# FIX: Define an interface in the consumer, implement in the provider
# service.ts defines IRepository interface, uses it
# repository.ts implements IRepository, doesn't import service.ts
# Wire them together in a composition root (index.ts, container.ts)
```

**Resolution:** Apply dependency inversion principle — depend on abstractions, not concretions.

### Pattern 4: Barrel File Cycles

```
# BEFORE (circular — hidden by barrel):
# src/utils/index.ts re-exports from auth.ts and user.ts
# auth.ts imports from src/utils (gets user.ts through barrel)
# user.ts imports from src/utils (gets auth.ts through barrel)

# FIX: Import directly, not through barrel
# auth.ts imports from src/utils/formatDate.ts (specific file)
# user.ts imports from src/utils/validateInput.ts (specific file)
```

**Resolution:** Replace barrel imports with direct imports to the specific file needed.

## TypeScript-Specific: Type-Only Cycles

In TypeScript, `import type` does NOT create a runtime circular dependency. These are safe:

```typescript
// This is FINE — type-only imports are erased at compile time
import type { UserType } from './user';
```

Only flag circular dependencies involving runtime imports (`import { ... }` without `type`).

## Resolution Priority

When you find circular deps during modularization, fix them in this order:

1. **Extract shared types** to a `types/` directory (easiest, lowest risk)
2. **Replace barrel imports** with direct imports (easy, medium impact)
3. **Extract the smaller side** of the cycle into its own module (medium effort)
4. **Apply dependency inversion** with interfaces (most effort, best long-term)

## Prevention

After modularization is complete, add preventative tooling:

```bash
# Add to CI/CD:
npx madge --circular --extensions ts,tsx src/ && echo "No cycles" || exit 1

# Or add ESLint rule:
# "import/no-cycle": ["error", { "maxDepth": 3 }]
```
