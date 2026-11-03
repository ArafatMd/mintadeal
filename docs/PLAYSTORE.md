# Publishing on Google Play

Two apps go on Google Play for everyone. The rider app goes to riders only, through Play's internal testing.

| App | Play Store name | App ID (permanent) | How people get it |
|---|---|---|---|
| `apps/customer_app` | Mintadeal | `com.mintadeal.app` | Google Play, public |
| `apps/vendor_app` | Mintadeal for Shops | `com.mintadeal.shop` | Google Play, public. Also used by pop-up stalls |
| `apps/delivery_app` | Mintadeal Delivery | `com.mintadeal.rider` | Play internal testing (invite by email), or an APK |

The admin website stays a website.

The app IDs above can never be changed once an app is uploaded.

## 1. Create the Play developer account (one-time, US$25)

Go to https://play.google.com/console/signup.

- **Organisation account (recommended if Mintadeal is a registered company or LLP).** Shows "Mintadeal" as the
  publisher and has no tester rule. It needs a D-U-N-S number for the company (free from Dun & Bradstreet; it can
  take a few days to two weeks), the company's website (mintadeal.com) and a phone and email on the company's
  domain or name.
- **Personal account.** Quicker to open, but Google requires each new app to run a **closed test with at least 12
  testers for 14 days in a row** before it can be published to everyone, and your own name is shown as the
  developer.

Google also verifies your identity, which can take a few days. Start this first.

## 2. Make the upload key (once, on your computer)

Google signs the apps it delivers; you sign what you upload with your own **upload key**. One key for all three
apps is fine.

1. In the repo folder, create a folder `android-keys` (git ignores it).
2. Create the key. `keytool` comes with Android Studio's Java (on Windows: `"C:\Program Files\Android\Android Studio\jbr\bin\keytool"`):

   ```bash
   keytool -genkeypair -v -keystore android-keys/upload.jks -storetype JKS -keyalg RSA -keysize 2048 \
     -validity 10000 -alias upload
   ```

   Choose a long password. It asks for your name and city; anything reasonable is fine.
3. Create `android-keys/key.properties`:

   ```properties
   storeFile=upload.jks
   storePassword=the password you chose
   keyAlias=upload
   keyPassword=the password you chose
   ```

4. **Back up `upload.jks` and the password** in your password manager, next to the server key. If you lose it you
   can ask Google to reset it, but that takes days.

Without `android-keys/key.properties`, release builds are signed with the debug key and the build prints a warning;
Google Play rejects those.

## 3. Build

Run these from the repo folder on your computer:

```bash
cd apps/customer_app
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.mintadeal.com
# -> build/app/outputs/bundle/release/app-release.aab

cd ../vendor_app
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.mintadeal.com

cd ../delivery_app
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.mintadeal.com
# or, for an APK you send to riders yourself:
flutter build apk --release --dart-define=API_BASE_URL=https://api.mintadeal.com
```

**Every update needs a higher build number.** In the app's `pubspec.yaml`, `version: 1.0.0+1` means version 1.0.0,
build 1. For the next upload change it to `1.0.1+2`, then `1.0.2+3`, and so on. The number after `+` must always go
up.

## 4. A test login for Google's reviewers

Reviewers cannot receive our SMS codes. Give them a fixed number and code:

1. On the server, add to `deploy/.env` a number nobody owns and a 6-digit code of your choice:

   ```
   REVIEW_PHONES=9000000999
   REVIEW_CODE=246810
   ```

2. Restart the API: `docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env up -d mintadeal-api`
3. In Play Console, under **App content, App access**, choose "All or some functionality is restricted" and add:
   - Username: `9000000999`
   - Password: `246810`
   - Instructions: "Enter the phone number, tap Send code, then enter the code. No SMS is sent for this number.
     In Mintadeal for Shops, the reviewer can choose 'Stall for a few days' to try a pop-up stall, or register a
     shop, which then waits for our review."
4. After the apps are approved you can keep it for future reviews. If a reviewer opens a pop-up stall, its listing
   shows the test number; take it down from the admin website (Pop-ups).

## 5. Fill in Play Console for each app

### Store listing

Prepare for each app:

- App icon 512 × 512 PNG.
- Feature graphic 1024 × 500.
- At least 2 phone screenshots; 4 to 6 is better. Take them on a phone from the live app.

Suggested texts:

**Mintadeal**
- Short description (max 80): `Deals from shops near you in Bengaluru. Order, pick up or get it delivered.`
- Full description:

  > Mintadeal shows you the offers running in shops around you in Bengaluru: groceries, meat and fish, bakery,
  > clothing, hardware, salons, hotels and more. Pop-up stalls, street sellers and market stalls near you appear
  > too.
  >
  > • See how far each shop is from you
  > • Order for delivery or pickup, or buy venue offers you use with a QR code
  > • Pay online or on delivery
  > • Follow your favourite shops and rate your orders
  > • Find pop-up stalls that are here today, and call or get directions

**Mintadeal for Shops**
- Short description: `Post deals for customers near you. Get orders. For shops and pop-up stalls.`
- Full description:

  > For shops in Bengaluru: list your products and offers, get orders from customers nearby, deliver yourself or
  > book a Mintadeal delivery partner, and see your earnings and payouts.
  >
  > Selling from a street stall, cart, market or event? Open a pop-up stall in 2 minutes: take photos, choose how
  > many days, and customers near you can find and call you. Available in English, ಕನ್ನಡ and हिंदी.

Category: **Shopping** for both. Contact email, phone and website `https://mintadeal.com`.

### App content

| Section | Answer |
|---|---|
| Privacy policy | `https://mintadeal.com/privacy` |
| App access | The reviewer login in step 4 |
| Ads | No, the app has no ads |
| Content rating | Fill the questionnaire. No violence or sexual content. Answer **yes** to "users can interact or exchange information" (support chat, phone numbers of pop-up stalls). Answer **yes** to "shares location with other users" for Mintadeal for Shops (a shop's or stall's place is shown to customers) |
| Target audience | 18 and over |
| News app | No |
| Government app | No |
| Financial features | None (payments are for goods, through Razorpay) |
| Health | None |
| Account deletion | Yes. URL `https://mintadeal.com/delete-account`; in the app: Account / My shop / stall screen, "Delete my account" |
| Data safety | See below |

### Data safety

Data is **encrypted in transit** (HTTPS): yes. People **can ask for their data to be deleted**: yes.

**Is data shared with third parties?** Answer no. Google does not count it as sharing when data goes to the shop,
rider or payment provider for an order the person asked for, or when a seller chooses to show their stall to
customers.

| Data type | Mintadeal | Mintadeal for Shops | Required? | Purpose |
|---|---|---|---|---|
| Phone number | Collected | Collected | Required | Account management, App functionality |
| Name | Collected | Collected | Optional | App functionality |
| Email address | Collected | Collected | Optional | Account management |
| Address (delivery address) | Collected | – | Optional (only for delivery) | App functionality |
| Approximate location | Collected | Collected | Optional | App functionality |
| Precise location | Collected | Collected | Optional | App functionality |
| Photos | Collected (profile photo) | Collected (shop, product and stall photos) | Optional | App functionality |
| Purchase history | Collected | Collected (orders received) | Required | App functionality |
| Other in-app messages | Collected (help requests) | Collected | Optional | Customer support |

Do not tick financial info. Card and UPI details are entered on Razorpay's payment page, not in the app.

### Permissions

- **Location** (both apps): used only while the app is open, when the person taps "Use my location" or "I'm here".
  Not in the background, so no background-location declaration is needed.
- **Camera** (Mintadeal for Shops): to scan customers' QR codes and to take photos of products and stalls.

## 6. Release

1. Create the app in Play Console with the names above, "App", "Free".
2. Upload the `.aab` under **Testing, Internal testing** first, install it from the invite link on your phone, and
   check sign-in, ordering, a pop-up stall and "Delete my account" with a spare number.
3. Personal account only: run the **closed test with 12 or more testers for 14 days** (friends, family, a few shops).
4. Go to **Production**, create a release with the same `.aab`, and send it for review. The first review usually
   takes a few days.

## The rider app

Create "Mintadeal Delivery" in Play Console and only ever use **Internal testing**. Add riders' Google account
emails to the testers list (up to 100), send them the invite link, and they install and get updates from Google
Play. Internal testing builds are not reviewed by Google and never appear in the store.

If a rider has no Google account on their phone, send them the APK from step 3 instead. They must allow "Install
unknown apps" for the app they open it with, and you send each new version yourself.
