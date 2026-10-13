#!/usr/bin/env bash
# Builds the four Flutter web apps on your computer and uploads them to the server.
#   DOMAIN=mintadeal.in SERVER=ubuntu@<elastic-ip> KEY=~/.ssh/skillpeck-prod.pem deploy/build-web.sh
set -euo pipefail
: "${DOMAIN:?set DOMAIN, e.g. mintadeal.in}"
: "${SERVER:?set SERVER, e.g. ubuntu@13.200.0.1}"
SSH="ssh${KEY:+ -i $KEY}"
cd "$(dirname "$0")/.."

for pair in customer_app:customer vendor_app:vendor admin_web:admin delivery_app:delivery; do
  app=${pair%%:*} target=${pair##*:}
  echo "== $app"
  (cd "apps/$app" && flutter build web --release --no-web-resources-cdn \
      --dart-define=API_BASE_URL="https://api.$DOMAIN")
  rsync -az --delete -e "$SSH" "apps/$app/build/web/" "$SERVER:mintadeal/deploy/web/$target/"
done
echo "Uploaded. The web container serves new files straight away."
