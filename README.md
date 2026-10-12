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
| `apps/customer_app/` | Customer app: Nearby, Deals in Bangalore, shops, following | Flutter 3.47 (Android, iOS, web) |
| `apps/vendor_app/` | Shop app: register, listings, stock, shop settings | Flutter 3.47 (Android, iOS, web) |
| `apps/delivery_app/` | Delivery partner app | Flutter 3.47 (Android, iOS, web) |
| `apps/admin_web/` | Admin website: vendor review, listing moderation, staff roles | Flutter 3.47 (web) |

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

Every sign-in code is **123456** in the dev profile.

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

## Building for release

- Web: `flutter build web --release --no-web-resources-cdn --dart-define=API_BASE_URL=https://api.example.com`
  (bundles the rendering engine instead of loading it from Google's CDN).
- Backend: set `JWT_SECRET`, `OTP_PEPPER`, `DB_URL`, `DB_USERNAME`, `DB_PASSWORD`, `PUBLIC_BASE_URL`,
  `CORS_ORIGINS` and `ADMIN_PHONES`. Never deploy with the `dev` profile: it fixes every OTP to 123456.
