#!/bin/bash
# Extract user-facing GET routes from a Laravel application
# Usage: ./extract-laravel-routes.sh [path-to-laravel-root]
#
# Outputs JSON array of auditable routes with:
#   - method, uri, name, middleware, auth_required

APP_DIR="${1:-.}"

if [ ! -f "$APP_DIR/artisan" ]; then
    echo "Error: Not a Laravel project (no artisan file found in $APP_DIR)"
    exit 1
fi

cd "$APP_DIR" || exit 1

# Extract routes as JSON, filter to GET-only web routes
php artisan route:list --method=GET --json 2>/dev/null | python3 -c "
import json, sys

try:
    routes = json.load(sys.stdin)
except:
    print('[]')
    sys.exit(0)

# Filter to web routes, exclude internal/API/webhook
skip_prefixes = ['api/', 'webhooks/', '_', 'sanctum/', 'livewire/']
skip_names = ['debugbar', 'telescope', 'horizon', 'pulse']

auditable = []
for r in routes:
    uri = r.get('uri', '')
    name = r.get('name', '') or ''
    middleware = r.get('middleware', '') or ''

    # Skip non-web routes
    if any(uri.startswith(p) for p in skip_prefixes):
        continue
    if any(s in name for s in skip_names):
        continue
    # Skip parameter-heavy routes (need specific IDs)
    param_count = uri.count('{')
    if param_count > 1:
        continue

    auth_required = 'auth' in str(middleware)

    auditable.append({
        'method': 'GET',
        'uri': '/' + uri.lstrip('/'),
        'name': name,
        'middleware': middleware,
        'auth_required': auth_required,
        'has_params': param_count > 0
    })

# Sort: public first, then auth required, then by URI
auditable.sort(key=lambda r: (r['auth_required'], r['uri']))

print(json.dumps(auditable, indent=2))
" 2>/dev/null

# Fallback: if php artisan fails, parse route files directly
if [ $? -ne 0 ]; then
    echo "Warning: artisan route:list failed, falling back to file parsing" >&2
    grep -E "Route::(get|view)\(" routes/web.php 2>/dev/null | \
        sed "s/.*['\"]\/\?\([^'\"]*\)['\"].*/\/\1/" | \
        sort -u | \
        python3 -c "
import json, sys
routes = [{'method': 'GET', 'uri': line.strip(), 'name': '', 'middleware': '', 'auth_required': True, 'has_params': '{' in line} for line in sys.stdin if line.strip()]
print(json.dumps(routes, indent=2))
"
fi
