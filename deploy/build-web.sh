#!/usr/bin/env bash
# Builds the four Flutter web apps on your computer and uploads them to the server.
#
#   deploy/build-web.sh
#
# The first run asks for the domain, server and key and saves them in deploy/web.env (not in git), so later runs
# need no settings. Edit or delete that file to change them. Values given on the command line win:
#   DOMAIN=mintadeal.com SERVER=ubuntu@<elastic-ip> KEY=~/.ssh/skillpeck-prod.pem deploy/build-web.sh
set -euo pipefail
cd "$(dirname "$0")/.."
SETTINGS=deploy/web.env

if [ -f "$SETTINGS" ]; then
  # Only fill in what the command line did not set.
  while IFS='=' read -r name value; do
    case "$name" in DOMAIN|SERVER|KEY) [ -z "${!name:-}" ] && printf -v "$name" '%s' "$value" ;; esac
  done < "$SETTINGS"
fi

if [ -z "${DOMAIN:-}" ] || [ -z "${SERVER:-}" ]; then
  echo "First run: tell me where to upload. This is saved in $SETTINGS for next time."
  read -r -p "Domain [mintadeal.com]: " answer; DOMAIN=${DOMAIN:-${answer:-mintadeal.com}}
  read -r -p "Server, e.g. ubuntu@15.206.219.113: " answer; SERVER=${SERVER:-$answer}
  read -r -p "SSH key file, e.g. ~/Downloads/skillpeck-prod.pem (empty for none): " answer; KEY=${KEY:-$answer}
  KEY=${KEY/#\~/$HOME}
  [ -n "$SERVER" ] || { echo "A server is needed."; exit 1; }
  printf 'DOMAIN=%s\nSERVER=%s\nKEY=%s\n' "$DOMAIN" "$SERVER" "$KEY" > "$SETTINGS"
  chmod 600 "$SETTINGS"
  echo "Saved $SETTINGS."
fi

KEY=${KEY:-}
KEY=${KEY/#\~/$HOME}
SSH="ssh${KEY:+ -i $KEY}"
echo "Uploading to $SERVER for $DOMAIN"
$SSH "$SERVER" 'mkdir -p ~/mintadeal/deploy/web && test -w ~/mintadeal/deploy/web' \
  || { echo "Cannot write ~/mintadeal/deploy/web on the server; run: sudo chown -R ubuntu ~/mintadeal/deploy/web"; exit 1; }

for pair in customer_app:customer vendor_app:vendor admin_web:admin delivery_app:delivery; do
  app=${pair%%:*} target=${pair##*:}
  echo "== $app"
  (cd "apps/$app" && flutter build web --release --no-web-resources-cdn \
      --dart-define=API_BASE_URL="https://api.$DOMAIN")
  rsync -az --delete -e "$SSH" "apps/$app/build/web/" "$SERVER:mintadeal/deploy/web/$target/"
done
echo "Uploaded. The web container serves new files straight away."
