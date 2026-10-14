# Road distances (optional)

Out of the box Mintadeal shows **approximate straight-line distances** ("~1.3 km"). They come from the
customer's location (GPS, or the centre of the area they chose) and the shop's pin.

With a small routing server on the same machine, shop cards, shop pages and deals show the **distance and
time by road** instead ("1.8 km · 10 min"), and partner deliveries are priced by road distance. The routing
server is [OSRM](https://project-osrm.org/) with OpenStreetMap data: open source, no API key, no per-request
cost. It uses about 300-500 MB of memory for Bengaluru.

## What changes when it is on

| | Without routing | With routing |
|---|---|---|
| Shop cards, shop page, deals | ~1.3 km | 1.8 km · 10 min |
| Partner delivery cost to the shop | straight-line km | road km |
| Which shops appear, and their order | straight-line km | straight-line km (unchanged) |
| Whether a shop delivers to an address | straight-line km against the shop's radius | unchanged |

Times are OSRM's empty-road times multiplied by 1.6 for city traffic (`mintadeal.routing.duration-factor`).
They are a guide, not a promise.

If the routing server is slow (over 1.5 s) or down, the API quietly falls back to straight-line distances,
waits 30 seconds before asking it again, and logs one warning. Road distances are cached for 6 hours.

## Setting it up on the server

1. Build the map data (5-15 minutes; needs about 2 GB of free memory, so add swap on a small instance):

   ```bash
   cd ~/mintadeal && git pull
   bash deploy/prepare-osrm.sh
   ```

   If memory is short, add a temporary swap file first:

   ```bash
   sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile
   ```

2. Start the routing server:

   ```bash
   docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env --profile routing up -d mintadeal-osrm
   ```

3. In `deploy/.env` set `OSRM_URL=http://mintadeal-osrm:5000`, then restart the API:

   ```bash
   docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env up -d mintadeal-api
   ```

4. Check it: this should print `"code":"Ok"` and a distance in metres.

   ```bash
   docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env exec mintadeal-api \
     bash -c 'exec 3<>/dev/tcp/mintadeal-osrm/5000 && printf "GET /route/v1/driving/77.6474,12.9116;77.6245,12.9352 HTTP/1.0\r\n\r\n" >&3 && cat <&3' | tail -c 300
   ```

## Keeping it up to date

New roads appear in OpenStreetMap all the time. Every month or two:

```bash
bash deploy/prepare-osrm.sh
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env --profile routing restart mintadeal-osrm
```

## Switching it off

Empty `OSRM_URL` in `deploy/.env`, restart `mintadeal-api`, then
`docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env --profile routing stop mintadeal-osrm`.

## Maps in the apps

The map where shops place their pin, and the one admins see, use OpenStreetMap's public tiles with the
required "© OpenStreetMap contributors" credit. That is fine for the small number of map views from shop
setup and admin checks. If maps are later shown to every customer, switch to a tile provider with a plan
(for example MapTiler or Stadia Maps) or host tiles yourself, as OpenStreetMap's tile servers are not meant
for heavy app traffic.
