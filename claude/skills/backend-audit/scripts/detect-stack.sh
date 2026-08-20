#!/usr/bin/env bash
# detect-stack.sh — identify backend framework, ORM, HTTP client, and cache layer.
# Usage: detect-stack.sh [TARGET_DIR]   (defaults to current directory)
# Read-only. Prints a small report to stdout.
# NOT -e: this is all best-effort detection — a failing `exists`/`grep` must not abort the script.
set -uo pipefail

DIR="${1:-.}"
cd "$DIR"

have() { command -v "$1" >/dev/null 2>&1; }
# Prefer ripgrep if present, else grep -r. Both quiet, case-insensitive, files-with-matches.
# Detect only against FIRST-PARTY source — exclude vendored deps / framework / build artifacts,
# otherwise every framework's bundled libraries match and detection becomes meaningless.
scan() { if have rg; then rg -l -i --no-messages -g '!vendor' -g '!node_modules' -g '!.git' -g '!build' -g '!builds' -g '!writable' -g '!overlay' -g '!dist' -g '!public' -e "$1" . 2>/dev/null | head -1; \
         else grep -rEIl -i --exclude-dir=node_modules --exclude-dir=vendor --exclude-dir=.git --exclude-dir=build --exclude-dir=builds --exclude-dir=writable --exclude-dir=overlay --exclude-dir=dist --exclude-dir=public -e "$1" . 2>/dev/null | head -1; fi; }
exists() { [ -e "$1" ] && echo "$1"; }

echo "# Stack detection — $DIR"
echo

echo "## Framework"
exists composer.json >/dev/null && grep -qi 'codeigniter4' composer.json 2>/dev/null && echo "- CodeIgniter 4 (PHP)"
exists composer.json >/dev/null && grep -qi 'laravel/framework' composer.json 2>/dev/null && echo "- Laravel (PHP)"
exists composer.json >/dev/null && grep -qi 'symfony/' composer.json 2>/dev/null && echo "- Symfony (PHP)"
exists package.json >/dev/null && grep -qi '"express"' package.json 2>/dev/null && echo "- Express (Node)"
exists package.json >/dev/null && grep -qiE '"(next|fastify|@nestjs/core|koa)"' package.json 2>/dev/null && echo "- Node framework (Next/Fastify/Nest/Koa — see package.json)"
{ exists requirements.txt; exists pyproject.toml; } >/dev/null 2>&1
grep -rqi 'fastapi' requirements.txt pyproject.toml 2>/dev/null && echo "- FastAPI (Python)"
grep -rqi 'django' requirements.txt pyproject.toml 2>/dev/null && echo "- Django (Python)"
grep -rqi 'flask' requirements.txt pyproject.toml 2>/dev/null && echo "- Flask (Python)"
exists Gemfile >/dev/null && grep -qi 'rails' Gemfile 2>/dev/null && echo "- Rails (Ruby)"
exists go.mod  >/dev/null && echo "- Go module ($(grep -i -m1 'gin-gonic\|echo\|fiber' go.mod 2>/dev/null || echo 'net/http'))"
echo

echo "## ORM / query layer"
# Single-quoted patterns: \\ = one literal backslash to rg (PHP namespace), \$ = literal $, \. = literal dot.
[ -n "$(scan 'CodeIgniter\\Model|\$this->db|->getBuilder\(')" ] && echo "- CodeIgniter Query Builder / Model"
[ -n "$(scan 'Illuminate\\Database|Illuminate\\Eloquent|use Eloquent')" ] && echo "- Eloquent (Laravel)"
[ -n "$(scan '@prisma/client|PrismaClient')" ] && echo "- Prisma"
[ -n "$(scan 'sequelize')" ] && echo "- Sequelize"
[ -n "$(scan 'typeorm')" ] && echo "- TypeORM"
[ -n "$(scan 'sqlalchemy|SQLAlchemy')" ] && echo "- SQLAlchemy"
[ -n "$(scan 'django\.db|models\.Model')" ] && echo "- Django ORM"
[ -n "$(scan 'ActiveRecord|ApplicationRecord')" ] && echo "- ActiveRecord (Rails)"
echo

echo "## HTTP client (outbound)"
# Match real call-sites, not bare mentions, to avoid framework/config false positives.
[ -n "$(scan 'GuzzleHttp|curl_init|CURLOPT|::curlrequest')" ] && echo "- Guzzle / cURL (PHP)"
[ -n "$(scan 'axios|node-fetch|undici|got\.(get|post)')" ] && echo "- axios / fetch / got (Node)"
[ -n "$(scan 'import requests|requests\.(get|post|Session)|httpx\.(get|post|Client)')" ] && echo "- requests / httpx (Python)"
echo

echo "## Cache layer"
# Report cache USAGE, not config/deps — framework Config/Cache.php + composer.lock enumerate every
# handler (PredisHandler, etc.) even when caching is never actually called from app code.
CACHE_USE='cache\(\)->|Cache::remember|Cache::store|Cache::put|->remember\(|service\(.cache.\)|createClient\(|ioredis|new Redis\(|new Memcached\('
if [ -n "$(scan "$CACHE_USE")" ]; then
  echo "- Cache usage detected in app code"
  [ -n "$(scan 'createClient\(|ioredis|new Redis\(|Predis\\Client|Cache::store\(.redis|cache\(.redis')" ] && echo "  · backend: Redis"
  [ -n "$(scan 'new Memcached\(|new Memcache\(')" ] && echo "  · backend: Memcached"
else
  echo "- (no cache usage in app code — caching opportunity; note: a driver may be installed but unused)"
fi
echo

echo "## Endpoint hints"
for f in app/Config/Routes.php config/routes.rb urls.py; do exists "$f" >/dev/null && echo "- routes file: $f"; done
[ -n "$(scan '@app\.(get|post|put|delete)|@router\.')" ] && echo "- FastAPI decorators present"
[ -n "$(scan 'router\.(get|post)|app\.(get|post)')" ] && echo "- Express/Node routes present"
echo
echo "Detection complete. Use this to scope passes 2–13 (see references/passes.md)."
