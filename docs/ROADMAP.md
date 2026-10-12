# MVP build plan

Each stage ships the backend and every app that uses it together, so a stage ends with something
working from end to end rather than an API nobody calls.

| Stage | Backend | Customer app | Vendor app | Delivery app | Admin website | Status |
|---|---|---|---|---|---|---|
| **1. Foundation** | Phone OTP sign-in, JWT, roles, audit trail, image upload | Sign-in | Sign-in | Sign-in (delivery partners only) | Sign-in (admins only) | Done |
| **2. Shops and discovery** | Vendor onboarding and review; products and venue offers; Nearby and Deals in Bangalore rules; follow shops | Area picker, Nearby, Bangalore, search and filters, listing detail, storefront, follow | Register shop, review status, listings, publish/pause, stock, shop and delivery settings | Profile shell | Vendor queue, approve/reject/suspend, internal vendor type, listing moderation, staff roles | Done |
| **3. Orders** | Cart, multi-shop checkout into sub-orders, price snapshots, stock reservation, acceptance timeout and auto-cancel, rejection reasons, pay on delivery/pickup, Razorpay Payment Links with signed webhook, refunds, Razorpay and 2Factor settings | Cart, checkout, payment hand-off, my orders, order timeline | Order inbox with alert and badge, accept/reject, ready, out for delivery, complete | | Order search, cancel and refund, Integrations settings | Done |
| **4. Venue QR and delivery** | Single-use QR for venue offers; delivery jobs; partner booking with cost shown to the shop; cost recovery ledger | QR in order, live delivery status | Scan QR, request delivery partner | Job list, pickup, proof of delivery, status updates | Delivery jobs, assign or cancel riders, shop dues | Done |
| **5. Payments and payouts** | Commission, double-entry ledger, payout batches (RazorpayX or manual), refund retries, WhatsApp order alerts | UPI prepay, refunds | Earnings and payouts | | Money overview, commission rates, payouts, failed refunds, message log | Done |
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

## Decisions taken in Stage 3

- **Brand theme from the logo:** orange `#E46C0A` and red `#D51C29`. Buttons use a deeper orange `#B9530A`
  so white text stays readable.
- **One checkout, one order per shop.** Offers and products from the same shop become separate orders, because
  offers are used at the venue and products are delivered or picked up.
- **Stock is reserved when the order is placed** and returned if it is cancelled, rejected or never paid.
- **Shops have 15 minutes to accept** (configurable), then the order is cancelled and refunded automatically.
- **Unpaid online checkouts close after 30 minutes**, after one last check with Razorpay.
- **Razorpay Payment Links** rather than the in-app SDK: the same hosted page works from Android, iOS and web,
  and keeps card data off our systems. Split settlement to shops (Razorpay Route) is Stage 5.
- **Venue offers are always paid online** and confirmed automatically on payment. Until the QR code arrives in
  Stage 4, the shop checks the order number and marks it used.
- **New-order alerts poll every 20 seconds** while the shop app is open. WhatsApp/SMS alerts come in Stage 5.

## Decisions taken in Stage 4

- **Venue offer QR:** a random 192-bit code checked by the server, issued when the offer is paid. It works once,
  only at the shop that sold it, only within the offer's dates. One QR covers every person in the order.
  If scanning fails, the shop enters the order number and the last 4 digits of the customer's phone.
- **The shop never sees the QR code itself**, and cannot mark a venue offer used without it.
- **Unused offers that expire stay paid.** The QR stops working; refunds for unused offers are an admin decision
  until the business sets a per-offer rule.
- **Riders take jobs from a shared board** (first come, first served; two riders cannot take the same job), or an
  admin assigns one by phone number. A rider sees the customer's phone and exact address only after taking the job.
- **Handover needs the customer's 4-digit delivery code.** Five wrong tries lock the job until support steps in.
- **Partner cost = ₹30 + ₹8 per started km** (configurable), shown to the shop before booking and charged when the
  rider picks up. A shop with more than ₹2,000 unpaid cannot book more riders. Payout deductions are Stage 5.
- **A failed delivery returns the order to the shop**, which can book another rider. Cancelling an order closes its
  delivery job.
- **Rider location tracking is not built yet**; customers see milestones (rider assigned, picked up, delivered).

## Decisions taken in Stage 5

- **Commission is a percentage of the item price** on completed orders (default 5% until an admin sets rates, with
  optional per-category rates). The shop keeps its own delivery fee. The rate is fixed on the order when it is
  placed. Mintadeal's own catalogue pays no commission.
- **Double-entry ledger.** Every money movement is a journal whose entries sum to zero, posted at most once per
  event, so retried webhooks and duplicate clicks never count money twice. The admin Money page flags any imbalance.
- **One balance per shop.** Online earnings, commission (also on pay-on-delivery orders) and delivery charges all
  net into it. A shop's delivery-booking limit uses what it owes after its earnings are netted off.
- **Payouts are batched by an admin** and either sent through RazorpayX (automatic, confirmed by webhook) or paid by
  bank/UPI and recorded with the reference. Shops without a UPI ID or bank account are listed as skipped. A failed or
  cancelled payout returns the money to the shop's balance. Minimum payout ₹100.
- **Mintadeal collects online payments and pays shops out.** Before going live with real money, confirm with your
  CA/lawyer whether this needs Razorpay Route (split settlement to shops' linked accounts) instead, so that
  Mintadeal does not hold shops' money. The ledger and payout records would stay; only the payout step changes.
- **WhatsApp Cloud API with approved templates** for alerts: new orders to the shop, progress (accepted, ready, out
  for delivery, completed, cancelled) to the customer. Sent after the order change is saved, in the background, and
  logged; a failing provider never blocks an order. Push notifications in the apps are not built yet.
