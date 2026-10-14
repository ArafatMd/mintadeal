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
  document.querySelectorAll("[data-shop]").forEach((a) => (a.href = cfg.shopUrl || a.href));
  const todo = (el) => {
    el.textContent = "To be added";
    el.classList.add("todo");
  };
  document.querySelectorAll("[data-fill]").forEach((el) => {
    const key = el.getAttribute("data-fill");
    let value = cfg[key];
    if (key === "legalName" && !value) value = "Mintadeal";
    if (!value) return todo(el);
    if (key === "phone" || key === "whatsapp") {
      const digits = value.replace(/\D/g, "").slice(-10);
      el.textContent = "+91 " + digits.replace(/(\d{5})(\d{5})/, "$1 $2");
      if (el.tagName === "A") el.href = key === "whatsapp" ? "https://wa.me/91" + digits : "tel:+91" + digits;
    } else if (key === "email" || key === "grievanceEmail") {
      el.textContent = value;
      if (el.tagName === "A") el.href = "mailto:" + value;
    } else {
      el.textContent = value;
    }
  });
  document.querySelectorAll("[data-year]").forEach((el) => (el.textContent = new Date().getFullYear()));
})();
