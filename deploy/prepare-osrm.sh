#!/usr/bin/env bash
# Builds the road map for Bengaluru that the optional mintadeal-osrm service routes on. Run on the server from the
# repo folder; it takes 5-15 minutes and needs about 2 GB of free memory (add swap on a small instance).
# Re-run it every month or two to pick up new roads, then restart mintadeal-osrm.
#
#   bash deploy/prepare-osrm.sh
set -euo pipefail

cd "$(dirname "$0")"
OUT=osrm
IMAGE=ghcr.io/project-osrm/osrm-backend:v5.27.1
SOURCE=https://download.geofabrik.de/asia/india/southern-zone-latest.osm.pbf
# Bengaluru and its outskirts: west,south,east,north.
BBOX=77.30,12.70,77.90,13.25

if ! command -v osmium >/dev/null; then
  echo "Installing osmium (cuts the Bengaluru area out of the South India map)..."
  sudo apt-get update -qq && sudo apt-get install -y -qq osmium-tool
fi

mkdir -p "$OUT/work"
echo "Downloading OpenStreetMap data for South India (about 400 MB)..."
curl -fL --retry 3 -o "$OUT/work/south.osm.pbf" "$SOURCE"

echo "Cutting out Bengaluru..."
osmium extract --overwrite -b "$BBOX" -o "$OUT/work/bengaluru.osm.pbf" "$OUT/work/south.osm.pbf"

echo "Building the road network (car profile)..."
docker run --rm -v "$PWD/$OUT/work:/data" "$IMAGE" osrm-extract -p /opt/car.lua /data/bengaluru.osm.pbf
docker run --rm -v "$PWD/$OUT/work:/data" "$IMAGE" osrm-partition /data/bengaluru.osrm
docker run --rm -v "$PWD/$OUT/work:/data" "$IMAGE" osrm-customize /data/bengaluru.osrm

# Swap the new files in only once everything above worked, so a failed rebuild leaves the old map running.
rm -f "$OUT"/bengaluru.osrm*
mv "$OUT"/work/bengaluru.osrm* "$OUT"/
rm -rf "$OUT/work"
echo
echo "Done. Next:"
echo "  docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env --profile routing up -d mintadeal-osrm"
echo "  set OSRM_URL=http://mintadeal-osrm:5000 in deploy/.env, then:"
echo "  docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env up -d mintadeal-api"
