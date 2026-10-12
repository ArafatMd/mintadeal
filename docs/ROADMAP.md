# MVP build plan

Each stage ships the backend and every app that uses it together, so a stage ends with something
working from end to end rather than an API nobody calls.

| Stage | Backend | Customer app | Vendor app | Delivery app | Admin website | Status |
|---|---|---|---|---|---|---|
| **1. Foundation** | Phone OTP sign-in, JWT, roles, audit trail, image upload | Sign-in | Sign-in | Sign-in (delivery partners only) | Sign-in (admins only) | Done |
| **2. Shops and discovery** | Vendor onboarding and review; products and venue offers; Nearby and Deals in Bangalore rules; follow shops | Area picker, Nearby, Bangalore, search and filters, listing detail, storefront, follow | Register shop, review status, listings, publish/pause, stock, shop and delivery settings | Profile shell | Vendor queue, approve/reject/suspend, internal vendor type, listing moderation, staff roles | Done |
| **3. Orders** | Cart, multi-shop checkout into sub-orders, price snapshots, acceptance timeout and auto-cancel, rejection reasons, pay on delivery/pickup | Cart, checkout, my orders, order timeline | Order alerts, accept/reject, prepare, mark delivered/collected | | Order search and exceptions | Next |
| **4. Venue QR and delivery** | Single-use QR for venue offers; delivery jobs; partner booking with cost shown to the shop; cost recovery ledger | QR in order, live delivery status | Scan QR, request delivery partner | Job list, pickup, proof of delivery, status updates | Delivery bookings, failures, dues | |
| **5. Payments and payouts** | Payment provider with split settlement, commission, payout statements, refunds, double-entry ledger, WhatsApp/SMS notifications | UPI prepay, refunds | Earnings and payouts | | Reconciliation, payout batches | |
| **6. Pilot hardening** | Ratings, support tickets, rate limiting, monitoring, backups | Ratings, help | Performance stats | | Support queue | |

## Decisions taken in Stages 1-2

- **Admin website is Flutter web** so the whole frontend is one language and shares `mintadeal_core`.
- **One modular backend**, no microservices, as the architecture document recommends for the MVP.
- **Phone OTP sign-in for everyone.** SMS sending is behind `SmsSender`; until a provider is connected the
  code is only logged (never the code itself) and the dev profile fixes it to 123456.
- **Location is a Bengaluru area picker** with coordinates; GPS can replace it without API changes.
- **Delivery partners are users with the DELIVERY_AGENT role**, added by an admin. That covers both
  Mintadeal riders and a partner's riders signing in to the delivery app.
- **Money is stored in paise** (integer minor units) everywhere.
- **Images are stored on local disk** for the MVP; move to object storage before running more than one server.
