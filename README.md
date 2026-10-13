# Mintadeal

Local stores, local deals, local customers. A Bengaluru-first marketplace where neighbourhood shops
list products and venue offers, and customers nearby discover them and order.

The business model is in [`Mintadeal_Business_Architecture_v2.pdf`](Mintadeal_Business_Architecture_v2.pdf);
the build plan is in [`docs/ROADMAP.md`](docs/ROADMAP.md).

## Repository layout

| Path | What it is | Stack |
|---|---|---|
| `backend/` | Marketplace API (one modular application) | Java 25, Spring Boot 4.1, PostgreSQL, Flyway |
| `packages/mintadeal_core/` | Shared Dart code: API client, models, phone sign-in, theme, widgets | Dart 3.13 |
| `apps/customer_app/` | Customer app: Nearby, Deals in Bangalore, shops, following, cart, checkout, orders | Flutter 3.47 (Android, iOS, web) |
| `apps/vendor_app/` | Shop app: register, listings, stock, shop settings, order inbox, QR scanner, delivery partner booking, earnings and payouts | Flutter 3.47 (Android, iOS, web) |
| `apps/delivery_app/` | Delivery partner app: job board, pickup, handover with the customer's code | Flutter 3.47 (Android, iOS, web) |
| `apps/admin_web/` | Admin website: vendor review, orders, delivery, money and payouts, commission, listing moderation, message log, integrations, staff roles | Flutter 3.47 (web) |

The Flutter projects are one [pub workspace](https://dart.dev/tools/pub/workspaces): run `flutter pub get`
once at the repository root.

## Run it locally

Prerequisites: JDK 25, Maven 3.9+, Flutter 3.47+, PostgreSQL 16+.

```bash
# 1. Database
createuser -P mintadeal          # password: mintadeal
createdb -O mintadeal mintadeal
createdb -O mintadeal mintadeal_test   # for backend tests

# 2. Backend with demo data (http://localhost:8080, API docs at /swagger-ui.html)
cd backend
mvn spring-boot:run -Dspring-boot.run.profiles=dev

# 3. Any app (from the repository root)
flutter pub get
cd apps/customer_app && flutter run -d chrome
```

On the Android emulator the backend is at `10.0.2.2`:
`flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080`.

### Demo accounts (dev profile)

Every sign-in code is **123456** in the dev profile while 2Factor is switched off. Online payment uses a
test payment page served by the backend (no money moves) until Razorpay is switched on in the admin website.

| Who | Phone |
|---|---|
| Admin | 9000000001 |
| Demo shops around HSR Layout | 9000000100 to 9000000106 |
| Delivery partner | 9000000201 |
| Customer | any other 10-digit mobile number |

## Tests

```bash
cd backend && mvn verify                     # API tests against PostgreSQL (mintadeal_test)
flutter analyze && flutter test              # from each app/package directory
```

## Payments and SMS (admin website → Integrations)

- **Razorpay:** enter the key ID, key secret and a webhook secret, save, then press *Test saved settings*.
  In the Razorpay dashboard add a webhook to the URL shown on the page for the events
  `payment_link.paid`, `payment_link.expired` and `payment_link.cancelled`, with the same webhook secret.
  Use `rzp_test_` keys first; the page shows TEST or LIVE mode. Customers pay on a Razorpay payment page;
  an order counts as paid only when Razorpay confirms it (signed webhook or a server-side status check).
- **2Factor:** enter the API key and, if you have one, the DLT-approved OTP template name. *Test* checks the key
  and balance, and sends one code if you give a number. When switched on, all sign-in codes go by SMS.

- **RazorpayX (payouts):** enter the RazorpayX account number. It uses the Razorpay keys above. Add the events
  `payout.processed`, `payout.failed` and `payout.reversed` to the same Razorpay webhook. When off, pay shops by
  bank or UPI and record the reference on the Payouts page.
- **WhatsApp:** create two utility templates in Meta WhatsApp Manager and enter their names with the phone number
  ID and a permanent access token. New order (to shops): `{{1}}` order number, `{{2}}` items, `{{3}}` total,
  `{{4}}` how it is fulfilled. Order update (to customers): `{{1}}` order number, `{{2}}` shop, `{{3}}` what happened.

Secrets are encrypted in the database with `SETTINGS_ENCRYPTION_KEY` and never shown again.

## Building for release

- Web: `flutter build web --release --no-web-resources-cdn --dart-define=API_BASE_URL=https://api.example.com`
  (bundles the rendering engine instead of loading it from Google's CDN).
- Backend: set `JWT_SECRET`, `OTP_PEPPER`, `SETTINGS_ENCRYPTION_KEY` (long, random, never changed), `DB_URL`,
  `DB_USERNAME`, `DB_PASSWORD`, `PUBLIC_BASE_URL` (the public HTTPS address, used for the Razorpay webhook),
  `CORS_ORIGINS` and `ADMIN_PHONES`. Never deploy with the `dev` profile: it fixes OTPs to 123456 and fakes payments.
- Server: see [docs/DEPLOY.md](docs/DEPLOY.md) for running it on the SkillPeck EC2 server with Docker Compose.
