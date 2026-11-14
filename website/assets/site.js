// Shared behaviour: header, mobile menu, scroll reveal, rotating words and contact details.
(function () {
  const cfg = window.MINTADEAL || {};

  // Header gets a border once the page scrolls.
  const nav = document.querySelector(".nav");
  const onScroll = () => nav && nav.classList.toggle("scrolled", window.scrollY > 8);
  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  // Mobile menu.
  const toggle = document.querySelector(".menu-toggle");
  if (toggle && nav) {
    toggle.addEventListener("click", () => {
      const open = nav.classList.toggle("open");
      toggle.setAttribute("aria-expanded", String(open));
    });
    nav.querySelectorAll("ul a").forEach((a) => a.addEventListener("click", () => nav.classList.remove("open")));
  }

  // Sections slide in as they come into view.
  const items = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window) {
    const io = new IntersectionObserver((entries) => {
      entries.forEach((e) => {
        if (e.isIntersecting) {
          e.target.classList.add("in");
          io.unobserve(e.target);
        }
      });
    }, { threshold: 0.15, rootMargin: "0px 0px -40px 0px" });
    items.forEach((el) => io.observe(el));
  } else {
    items.forEach((el) => el.classList.add("in"));
  }

  // Rotating words in the hero headline.
  document.querySelectorAll(".rotator").forEach((r) => {
    const words = Array.from(r.querySelectorAll("span"));
    if (words.length < 2) return;
    let i = 0;
    words[0].classList.add("on");
    setInterval(() => {
      words[i].classList.remove("on");
      words[i].classList.add("off");
      const prev = words[i];
      setTimeout(() => prev.classList.remove("off"), 600);
      i = (i + 1) % words.length;
      words[i].classList.add("on");
    }, 2400);
  });

  // App links and business details from site-config.js.
  document.querySelectorAll("[data-app]").forEach((a) => (a.href = cfg.appUrl || a.href));
  // "Get the app": phones go straight to the app, which offers to install itself. On a computer, show a QR code to
  // scan with the phone, with a link to install on the computer instead.
  const installUrl = (cfg.appUrl || "https://app.mintadeal.com") + "/?install=1";
  const onComputer = () => window.matchMedia("(min-width: 900px) and (pointer: fine)").matches;
  const openQr = () => {
    let box = document.getElementById("get-app");
    if (!box) {
      box = document.createElement("div");
      box.id = "get-app";
      box.className = "get-app";
      box.setAttribute("role", "dialog");
      box.setAttribute("aria-modal", "true");
      box.setAttribute("aria-label", "Get the Mintadeal app");
      box.innerHTML =
        '<div class="get-app-card">' +
        '<button class="get-app-close" aria-label="Close">×</button>' +
        "<h3>Get Mintadeal on your phone</h3>" +
        "<p>Scan with your phone camera, then tap <b>Install</b> (Android) or follow the steps to <b>Add to Home Screen</b> (iPhone).</p>" +
        '<img src="/assets/app-qr.svg" alt="QR code for app.mintadeal.com" width="220" height="220">' +
        '<a class="btn btn-red" href="' + installUrl + '">Install on this computer instead</a>' +
        "</div>";
      document.body.appendChild(box);
      const close = () => box.classList.remove("open");
      box.addEventListener("click", (e) => { if (e.target === box) close(); });
      box.querySelector(".get-app-close").addEventListener("click", close);
      document.addEventListener("keydown", (e) => { if (e.key === "Escape") close(); });
    }
    box.classList.add("open");
    box.querySelector(".get-app-close").focus();
  };
  document.querySelectorAll("[data-get-app]").forEach((a) => {
    a.href = installUrl;
    a.addEventListener("click", (e) => {
      if (!onComputer()) return;
      e.preventDefault();
      openQr();
    });
  });
  document.querySelectorAll("[data-shop]").forEach((a) => (a.href = cfg.shopUrl || a.href));
  const todo = (el) => {
    el.textContent = "To be added";
    el.classList.add("todo");
  };
  document.querySelectorAll("[data-fill]").forEach((el) => {
    const key = el.getAttribute("data-fill");
    if (key === "grievanceOfficer") {
      // Each officer's name with their own mail link.
      const officers = cfg.grievanceOfficers || [];
      if (!officers.length) return todo(el);
      el.textContent = "";
      officers.forEach((o, i) => {
        if (i) el.append(i === officers.length - 1 ? " and " : ", ");
        el.append(o.name + " (");
        const link = document.createElement("a");
        link.href = "mailto:" + o.email;
        link.textContent = o.email;
        el.append(link, ")");
      });
      return;
    }
    let value = cfg[key];
    if (key === "legalName" && !value) value = "Mintadeal";
    // WhatsApp is the support phone unless a different number is set.
    if (key === "whatsapp" && !value) value = cfg.phone;
    if (!value) return todo(el);
    if (key === "phone" || key === "whatsapp") {
      const digits = value.replace(/\D/g, "").slice(-10);
      el.textContent = "+91 " + digits.replace(/(\d{5})(\d{5})/, "$1 $2");
      if (el.tagName === "A") el.href = key === "whatsapp" ? "https://wa.me/91" + digits : "tel:+91" + digits;
    } else if (key === "email" || key === "grievanceEmail") {
      const addresses = value.split(",").map((v) => v.trim()).filter(Boolean);
      if (addresses.length > 1 && el.tagName === "A") {
        // Several addresses: one mail link each, separated by commas.
        const span = document.createElement("span");
        addresses.forEach((address, i) => {
          if (i) span.append(", ");
          const link = document.createElement("a");
          link.href = "mailto:" + address;
          link.textContent = address;
          span.append(link);
        });
        el.replaceWith(span);
        return;
      }
      el.textContent = addresses[0];
      if (el.tagName === "A") el.href = "mailto:" + addresses[0];
    } else {
      el.textContent = value;
    }
  });
  document.querySelectorAll("[data-year]").forEach((el) => (el.textContent = new Date().getFullYear()));
})();
