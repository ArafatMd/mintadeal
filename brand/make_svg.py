"""Builds the Mintadeal logo SVGs: wordmark from Sometype Mono Bold outlines, cart drawn by hand."""
import math, sys
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

RED = '#EB0A1E'
CHARCOAL = '#2B2B2B'
font = TTFont(sys.argv[1])
gs = font.getGlyphSet(); cmap = font.getBestCmap(); upem = font['head'].unitsPerEm
cap = font['OS/2'].sCapHeight or 700

def word(text, x, baseline, cap_px, gap=6.0, squeeze=0.86):
    """Path data for text with its baseline at y and capitals cap_px tall.

    The font is monospaced; letters are re-spaced by their outlines (gap px apart) and narrowed
    slightly, like the original lettering.
    """
    from fontTools.pens.boundsPen import BoundsPen
    s = cap_px / cap
    pen = SVGPathPen(gs)
    for ch in text:
        g = cmap[ord(ch)]
        bp = BoundsPen(gs); gs[g].draw(bp)
        xmin, _, xmax, _ = bp.bounds
        sx = s * squeeze
        gs[g].draw(TransformPen(pen, (sx, 0, 0, -s, x - xmin * sx, baseline)))
        x += (xmax - xmin) * sx + gap
    return pen.getCommands(), x - gap

def tag(cx, cy, angle):
    # A price tag: chamfered top, hole near the top. Local box 120 x 200 centred on (cx, cy).
    pts = [(-52, -82), (-22, -120), (22, -120), (52, -82), (52, 110), (-52, 110)]
    a = math.radians(angle)
    rot = lambda p: (cx + p[0] * math.cos(a) - p[1] * math.sin(a), cy + p[0] * math.sin(a) + p[1] * math.cos(a))
    d = 'M' + ' L'.join(f'{x:.1f},{y:.1f}' for x, y in map(rot, pts)) + ' Z'
    hx, hy = rot((0, -88))
    return f'<path d="{d}" fill="{RED}"/><circle cx="{hx:.1f}" cy="{hy:.1f}" r="12" fill="#fff"/>'

def wheel(cx, cy):
    return (f'<circle cx="{cx}" cy="{cy}" r="19" fill="none" stroke="{CHARCOAL}" stroke-width="8"/>'
            f'<circle cx="{cx}" cy="{cy}" r="6" fill="{CHARCOAL}"/>')

def cart():
    """The cart in a 512 x 512 box."""
    basket = '62,212 392,196 366,326 108,330'
    lines = []
    for k in range(-400, 800, 42):
        lines.append(f'<line x1="{k}" y1="160" x2="{k + 260}" y2="420"/>')
        lines.append(f'<line x1="{k}" y1="420" x2="{k + 260}" y2="160"/>')
    # Tags show above the rim and inside the basket, never below or beside it.
    return f'''<defs>
    <clipPath id="basket"><polygon points="{basket}"/></clipPath>
    <clipPath id="tags"><rect x="0" y="0" width="512" height="212"/><polygon points="{basket}"/></clipPath>
  </defs>
  <g clip-path="url(#tags)">{tag(132, 222, -22)}{tag(246, 196, -4)}{tag(342, 232, 20)}</g>
  <g clip-path="url(#basket)">
    <polygon points="{basket}" fill="{RED}"/>
    <g stroke="#fff" stroke-width="9">{''.join(lines)}</g>
  </g>
  <polyline points="48,200 104,334 330,334" fill="none" stroke="{RED}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>
  <polyline points="446,118 425,118 362,384 140,384" fill="none" stroke="{CHARCOAL}" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="460" cy="118" r="7" fill="{RED}"/>
  {wheel(152, 422)}{wheel(306, 422)}'''

# Full logo, laid out like the original: "Mint", a raised small "a", then "Deal" set lower, cart above "Deal".
STROKE = 'stroke="%s" stroke-width="2.5" stroke-linejoin="round"' % RED  # rounds the slab corners
mint, x = word('Mint', 12, 226, 106)
a, x2 = word('a', x + 12, 196, 56)
deal, x3 = word('Deal', x2 + 22, 250, 102)
width = math.ceil(x3 + 14)
cart_x = x2 + 22 + 55
logo = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} 270" width="{width}" height="270" role="img" aria-label="Mintadeal">
  <title>Mintadeal</title>
  <g transform="translate({cart_x - 18:.0f},-22) scale(0.4)">{cart()}</g>
  <path d="{mint}" fill="{RED}" {STROKE}/>
  <path d="{a}" fill="{RED}" {STROKE}/>
  <path d="{deal}" fill="{RED}" {STROKE}/>
</svg>
'''
mark = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512" role="img" aria-label="Mintadeal">
  <title>Mintadeal</title>
  {cart()}
</svg>
'''
open(sys.argv[2] + '/logo.svg', 'w').write(logo)
open(sys.argv[2] + '/mark.svg', 'w').write(mark)
print('logo width', width)
