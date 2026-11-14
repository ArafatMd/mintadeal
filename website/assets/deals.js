// Live deals on mintadeal.com: products and venue offers available across Bengaluru, whatever the visitor's
// location. Fills every element with `data-deals` (optionally `data-limit`); hides `data-deals-section` when
// there are none. "Buy now" opens that product in the app, ready to add to the cart and pay.
(function () {
  const cfg = window.MINTADEAL || {};
  const api = cfg.apiUrl || "https://api.mintadeal.com";
  const app = cfg.appUrl || "https://app.mintadeal.com";
  const grids = document.querySelectorAll("[data-deals]");
  if (!grids.length) return;

  const rupees = (minor) => "₹" + (minor / 100).toLocaleString("en-IN", { maximumFractionDigits: 2 });
  const el = (tag, cls, text) => {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  };

  const card = (item) => {
    const l = item.listing;
    const v = item.vendor || {};
    const a = el("a", "deal-card");
    a.href = app + "/?listing=" + encodeURIComponent(l.id);
    const pic = el("div", "deal-pic");
    if (l.imageUrl) {
      const img = el("img");
      img.src = l.imageUrl;
      img.alt = l.title;
      img.loading = "lazy";
      pic.append(img);
    } else {
      pic.append(el("span", "deal-pic-empty", "🛍️"));
    }
    if (l.discountPercent) pic.append(el("span", "deal-off", l.discountPercent + "% OFF"));
    const body = el("div", "deal-body");
    body.append(el("h3", null, l.title));
    body.append(el("p", "deal-shop", v.mintadealOwn ? "Sold by Mintadeal" : v.displayName || ""));
    const price = el("p", "deal-price");
    price.append(el("b", null, rupees(l.offerPriceMinor != null ? l.offerPriceMinor : l.priceMinor)));
    if (l.offerPriceMinor != null && l.offerPriceMinor < l.priceMinor) price.append(el("s", null, rupees(l.priceMinor)));
    body.append(price);
    body.append(el("p", "deal-how", item.venueOffer ? "Venue offer · use with a QR code" : "Delivered across Bengaluru"));
    body.append(el("span", "btn btn-red btn-sm deal-buy", "Buy now"));
    a.append(pic, body);
    return a;
  };

  fetch(api + "/api/discovery/bangalore?size=24")
    .then((r) => (r.ok ? r.json() : { items: [] }))
    .catch(() => ({ items: [] }))
    .then((page) => {
      const items = (page.items || []).filter((i) => i.listing);
      grids.forEach((grid) => {
        const limit = parseInt(grid.getAttribute("data-limit") || "24", 10);
        grid.textContent = "";
        if (!items.length) {
          const section = grid.closest("[data-deals-section]");
          if (section) section.hidden = true;
          else grid.append(el("p", "deals-empty", "New deals are being added. Open the app to see the shops near you."));
          return;
        }
        items.slice(0, limit).forEach((i) => grid.append(card(i)));
      });
    });
})();
