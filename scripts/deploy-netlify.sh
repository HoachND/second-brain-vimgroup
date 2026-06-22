#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ ! -f .env.netlify ]]; then
  echo "Missing .env.netlify"
  exit 1
fi

set -a
source ./.env.netlify
set +a

if [[ -z "${NETLIFY_AUTH_TOKEN:-}" ]]; then
  echo "Missing NETLIFY_AUTH_TOKEN in .env.netlify"
  exit 1
fi

if [[ -z "${NETLIFY_SITE_ID:-}" ]]; then
  if [[ -n "${NETLIFY_SITE_NAME:-}" ]]; then
    echo "NETLIFY_SITE_ID empty. Creating or linking site by name: ${NETLIFY_SITE_NAME}"
    CREATE_ARGS=(api createSite --data "{}")
    if [[ -n "${NETLIFY_TEAM_SLUG:-}" ]]; then
      CREATE_ARGS=(api createSite --data "{\"name\":\"${NETLIFY_SITE_NAME}\",\"account_slug\":\"${NETLIFY_TEAM_SLUG}\"}")
    else
      CREATE_ARGS=(api createSite --data "{\"name\":\"${NETLIFY_SITE_NAME}\"}")
    fi
    SITE_JSON=$(npx netlify "${CREATE_ARGS[@]}")
    SITE_ID=$(printf '%s' "$SITE_JSON" | python3 -c 'import sys,json; print(json.load(sys.stdin)["id"])')
    python3 - <<PY
from pathlib import Path
p = Path('.env.netlify')
s = p.read_text()
old = 'NETLIFY_SITE_ID=\n'
new = f'NETLIFY_SITE_ID={"$SITE_ID"}\n'
if old in s:
    s = s.replace(old, new, 1)
else:
    s += '\n' + new
p.write_text(s)
PY
    export NETLIFY_SITE_ID="$SITE_ID"
    echo "Created site: $NETLIFY_SITE_ID"
  else
    echo "Missing NETLIFY_SITE_ID. Add NETLIFY_SITE_ID or NETLIFY_SITE_NAME to .env.netlify"
    exit 1
  fi
fi

echo "Deploying to Netlify site: ${NETLIFY_SITE_ID}"
npx netlify deploy --prod --site "$NETLIFY_SITE_ID" --dir public --functions functions
