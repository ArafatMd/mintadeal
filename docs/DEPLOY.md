# Deploying Mintadeal next to SkillPeck

Mintadeal runs on the same EC2 server as SkillPeck, as a separate Docker Compose project in `~/mintadeal`.
SkillPeck is not changed except for one edit: its Caddy, which already holds ports 80/443, gets five more site
blocks and gets the HTTPS certificates for them.

```
Internet ──443──▶ SkillPeck Caddy ─┬─ SkillPeck sites (unchanged)
                                   ├─ api.mintadeal.com    ─▶ mintadeal-api:8080  ─▶ mintadeal-db (private network)
                                   └─ app/shop/admin/rider ─▶ mintadeal-web:8081-8084 (static Flutter builds)
```

| Address | What it is |
|---|---|
| `https://api.<domain>` | Backend API (Spring Boot) |
| `https://app.<domain>` | Customer app (web) |
| `https://shop.<domain>` | Vendor app (web) |
| `https://admin.<domain>` | Admin website |
| `https://rider.<domain>` | Delivery app (web) |

The domain is `mintadeal.com`, with DNS on Cloudflare.

Mintadeal uses about 0.5 GB of RAM when idle. It is capped at 1.7 GB: API 1 GB, database 512 MB, web and
backup about 200 MB. Its containers, volumes and network all start with `mintadeal`, so they never clash with
SkillPeck's `deploy_*` names.

## 1. Check the server has room

SSH in the way you do for SkillPeck, then run:

```bash
free -h          # "available" should be at least 2 GB
df -h /          # at least 5 GB free
```

If memory is tight, the biggest user is usually Ollama.

## 2. DNS (Cloudflare)

Add five **A** records pointing at the same Elastic IP as SkillPeck: `api`, `app`, `shop`, `admin` and `rider`.
Set each one to **DNS only** (grey cloud), the same as SkillPeck's records, so Caddy can get certificates.

The security group already allows 80/443, so it needs no change.

## 3. Find SkillPeck's Docker network

Mintadeal's API and web containers join the network that SkillPeck's Caddy is on:

```bash
cd ~/skillpeck
docker inspect $(docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env ps -q caddy) \
  --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}'
```

This usually prints `deploy_default`. If it prints something else, use that name for `EDGE_NETWORK` in step 5.
The database is on a private network and cannot be reached from SkillPeck's containers.

## 4. Get the code onto the server (read-only deploy key)

A GitHub deploy key works for only one repository, so Mintadeal needs its own key next to SkillPeck's:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/mintadeal_deploy -N "" -C "mintadeal-prod"
cat >> ~/.ssh/config <<'EOF'
Host github-mintadeal
  HostName github.com
  User git
  IdentityFile ~/.ssh/mintadeal_deploy
  IdentitiesOnly yes
EOF
cat ~/.ssh/mintadeal_deploy.pub
```

1. In GitHub, open **ArafatMd/mintadeal → Settings → Deploy keys → Add deploy key**.
2. Paste the public key and leave **write access off**.
3. Clone the repository:

```bash
git clone git@github-mintadeal:ArafatMd/mintadeal.git ~/mintadeal
cd ~/mintadeal
git checkout claude/nice-ride-1ju7bz   # until the work is merged into main
```

## 5. Secrets

```bash
cd ~/mintadeal
cp deploy/.env.example deploy/.env
chmod 600 deploy/.env
for v in DB_PASSWORD JWT_SECRET OTP_PEPPER SETTINGS_ENCRYPTION_KEY; do
  sed -i "s|^$v=.*|$v=$(openssl rand -base64 48 | tr -d '/+=\n')|" deploy/.env
done
sed -i "s|^FIRST_SIGNIN_CODE=.*|FIRST_SIGNIN_CODE=$(shuf -i 100000-999999 -n 1)|" deploy/.env
nano deploy/.env    # set DOMAIN, ADMIN_PHONES (your 10-digit number) and EDGE_NETWORK if step 3 differed
```

Save **`SETTINGS_ENCRYPTION_KEY`** in your password manager. It encrypts the Razorpay, 2Factor and WhatsApp
secrets in the database. If it is lost or changed, those settings must be entered again. `JWT_SECRET` and
`OTP_PEPPER` can be replaced; changing them signs everyone out.

## 6. Start Mintadeal

```bash
cd ~/mintadeal
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env up -d --build
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env logs -f mintadeal-api
```

The first build downloads Maven dependencies and takes about 5 minutes. Wait for `Started MintadealApplication`,
then press Ctrl+C. The database tables are created automatically on first start.

## 7. Upload the web apps (from your computer)

Flutter web is built on your computer and uploaded, the same way as SkillPeck. From the repository root:

```bash
DOMAIN=mintadeal.com SERVER=ubuntu@<elastic-ip> KEY=~/.ssh/<your-key>.pem deploy/build-web.sh
```

The script builds all four apps with `API_BASE_URL=https://api.mintadeal.com` and rsyncs them to
`~/mintadeal/deploy/web/`. New files are served immediately, with no restart.

## 8. Plug into SkillPeck's Caddy

1. Back up SkillPeck's Caddyfile:

   ```bash
   cd ~/skillpeck
   cp deploy/Caddyfile deploy/Caddyfile.bak-$(date +%F)
   ```

2. Add the Mintadeal blocks:

   ```bash
   cat ~/mintadeal/deploy/Caddyfile.mintadeal >> deploy/Caddyfile
   ```

3. Check the file before Caddy reloads it:

   ```bash
   docker run --rm -v "$PWD/deploy/Caddyfile:/etc/caddy/Caddyfile:ro" caddy:2-alpine \
     caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
   ```

4. Recreate Caddy. SkillPeck is down for a second or two:

   ```bash
   docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env up -d --force-recreate caddy
   docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env logs --tail 50 caddy
   ```

The Caddy logs should show certificates obtained for the five new names. If SkillPeck breaks, put back the
`.bak` file and run step 4 again.

The Caddyfile is part of the SkillPeck repository (`ArafatMd/oneworld`). Commit the same change there, or the
next `git pull` in `~/skillpeck` will conflict with it.

## 9. Check it works

```bash
curl -s https://api.mintadeal.com/actuator/health      # {"groups":["liveness","readiness"],"status":"UP"}
```

Then open `https://app.mintadeal.com`.

## 10. First sign-in and switching on 2Factor

Until 2Factor is set up, no SMS can be sent.

1. Open `https://admin.mintadeal.com` and enter one of the `ADMIN_PHONES`.
2. Use the `FIRST_SIGNIN_CODE` from `deploy/.env` as the OTP. Numbers listed in `ADMIN_PHONES` become admins on
   sign-in.
3. Go to **Integrations → 2Factor**, enter the API key, and press **Test** with your number.
4. Switch 2Factor on. From then on every code goes by SMS and `FIRST_SIGNIN_CODE` stops working.
5. Remove the code completely:

   ```bash
   cd ~/mintadeal
   sed -i 's/^FIRST_SIGNIN_CODE=.*/FIRST_SIGNIN_CODE=/' deploy/.env
   docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env up -d mintadeal-api
   ```

> While `FIRST_SIGNIN_CODE` is set and 2Factor is off, anyone who knows the code can sign in as any number,
> including the admin number. Do steps 1–5 in one sitting and never share the code.

Then:

- **Razorpay:** set it up under Integrations (see the README). The webhook URL is
  `https://api.mintadeal.com/api/webhooks/razorpay`.
- **WhatsApp and RazorpayX:** set up when you are ready.
- **Admin numbers:** to add more, put them in `ADMIN_PHONES` and restart `mintadeal-api`.

## Android apps

The Play Store and APK builds need the same API address:

```bash
cd apps/vendor_app   # or customer_app, delivery_app
flutter build apk --release --dart-define=API_BASE_URL=https://api.mintadeal.com
```

## Updating

```bash
cd ~/mintadeal && git pull
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env up -d --build mintadeal-api
```

If the apps changed, run `deploy/build-web.sh` again from your computer. Database migrations run on API start.
The API is unavailable for about 30 seconds while it restarts.

## Backups

- **Schedule:** every night at 03:00 IST the `mintadeal-backup` container writes two files to
  `~/mintadeal/deploy/backups/`: a database dump (`mintadeal-*.dump`) and the uploaded images
  (`files-*.tar.gz`).
- **Retention:** 14 days.
- **Off-server copies:** the EBS daily snapshot covers these files too. For a copy off the server, pull one
  now and then:

  ```bash
  rsync -az ubuntu@<elastic-ip>:mintadeal/deploy/backups/ ./mintadeal-backups/
  ```

To restore, stop the API, restore the database, restore the images, then start the API again:

```bash
cd ~/mintadeal
C="docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env"
$C stop mintadeal-api
$C exec -T mintadeal-db pg_restore -U mintadeal -d mintadeal --clean --if-exists < deploy/backups/mintadeal-YYYYMMDD-0300.dump
$C run --rm --no-deps -v "$PWD/deploy/backups:/b:ro" --entrypoint sh mintadeal-api \
  -c 'tar -xzf /b/files-YYYYMMDD-0300.tar.gz -C /data/files'
$C start mintadeal-api
```

## Troubleshooting

| Problem | Fix |
|---|---|
| **502 from a Mintadeal address** | Check `docker compose ... ps` in `~/mintadeal`. If the containers are up, `EDGE_NETWORK` is probably not Caddy's network; repeat step 3. |
| **`network deploy_default not found`** | SkillPeck was taken down with `down`, which removes its network. Start SkillPeck first, then run `up -d` for Mintadeal. |
| **Certificate errors** | Make sure the DNS records are grey-cloud and point at the Elastic IP, then read the Caddy logs. |
| **Sign-in code never arrives** | Check Integrations → 2Factor, and see the API logs: `logs --tail 100 mintadeal-api`. |
| **Removing Mintadeal** | `docker compose ... down` in `~/mintadeal` (add `-v` only to also delete its data), then remove the five blocks from SkillPeck's Caddyfile and recreate Caddy. |
