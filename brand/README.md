# Mintadeal logo

- `logo.svg`: the full logo (wordmark and cart), Toyota red `#EB0A1E` with a charcoal `#2B2B2B` cart frame.
- `mark.svg`: the cart on its own, for app icons and favicons.

The lettering is Courier Prime (SIL Open Font License) converted to outlines, so the SVGs need no font
installed. To change the logo, edit `make_svg.py` and run it with Courier Prime Regular:

```bash
pip install fonttools
python brand/make_svg.py CourierPrime-Regular.ttf brand
```

Then export PNGs from the SVGs (any SVG tool) for `packages/mintadeal_core/assets/logo.png`, each app's
`web/icons/` and `web/favicon.png`, and the Android `mipmap-*/ic_launcher.png` files.
