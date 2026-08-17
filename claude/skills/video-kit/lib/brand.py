#!/usr/bin/env python3
"""Pillow-rendered brand overlays that follow the BPG codebase exactly.

Typography + colour come from the real code (see brand_tokens.json `_source`):
  - display = Jost, body = DM Sans (tailwind.config.js / main.css)
  - palette = monochrome: ink #111111, white #fff, muted = white @58% on dark
  - logo    = the actual /images/bricklane-logo.svg: "BRICKLANE" in Inter 500
              (letter-spacing 6 @ size 28 in a 320x60 viewBox) + a triangle glyph
This ffmpeg build has no drawtext, so everything is a transparent PNG overlaid by
reel.py. render_all() returns {logo, hook, lower, endcard}.
"""
import json, os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
MUTED = (255, 255, 255, 148)   # white @58% — the site's --muted on a dark surface

def _hex(h):
    h = h.lstrip("#"); return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def load_tokens(path=None):
    return json.load(open(path or os.path.join(HERE, "brand_tokens.json")))

def font(kind, size, tk, weight=None):
    """Load a brand variable font (display=Jost / body=DM Sans / logo=Inter) at a weight."""
    path = os.path.join(HERE, "assets", "fonts", tk["fonts"][kind])
    w = weight if weight is not None else tk["weights"].get(kind, 400)
    try:
        f = ImageFont.truetype(path, size)
        try: f.set_variation_by_axes([w])
        except Exception: pass
        return f
    except Exception:
        return ImageFont.load_default()

def tracked_width(text, fnt, tracking):
    return sum(fnt.getlength(c) for c in text) + tracking * max(0, len(text) - 1)

def draw_tracked(d, x, y, text, fnt, fill, tracking):
    for c in text:
        d.text((x, y), c, font=fnt, fill=fill); x += fnt.getlength(c) + tracking

def fit_font(kind, text, max_w, start, tk, tracking=0, weight=None):
    s = start
    while s > 8:
        f = font(kind, s, tk, weight)
        if tracked_width(text, f, tracking) <= max_w: return f
        s -= 2
    return font(kind, max(8, s), tk, weight)

def render_logo(width, tk, color=(255, 255, 255, 240), shadow=True):
    """The actual bricklane-logo.svg (Inter 'BRICKLANE' + triangle), scaled to `width`."""
    sc = width / 320.0
    fsz = max(9, int(28 * sc)); track = 6 * sc
    f = font("logo", fsz, tk, tk["weights"]["logo"])
    H = int(52 * sc) + 2
    img = Image.new("RGBA", (width, H), (0, 0, 0, 0)); d = ImageDraw.Draw(img)
    asc, _ = f.getmetrics()
    tw = tracked_width(tk["wordmark"], f, track)
    x = (width - tw) / 2; y = int(38 * sc) - asc          # baseline at y=38 in viewBox
    if shadow:
        draw_tracked(d, x + max(1, sc), y + max(1, sc), tk["wordmark"], f, (0, 0, 0, 130), track)
    draw_tracked(d, x, y, tk["wordmark"], f, color, track)
    tri = [(172 * sc, 46 * sc), (184 * sc, 46 * sc), (178 * sc, 40 * sc)]   # SVG polygon
    if shadow: d.polygon([(a + max(1, sc), b + max(1, sc)) for a, b in tri], fill=(0, 0, 0, 130))
    d.polygon(tri, fill=color)
    return img

def _bottom_scrim(img, frac=0.44, strength=205):
    W, H = img.size; g = Image.new("L", (1, H), 0); top = int(H * (1 - frac))
    for y in range(top, H): g.putpixel((0, y), int(strength * ((y - top) / (H - top))))
    s = Image.new("RGBA", (W, H), (10, 10, 10, 0)); s.putalpha(g.resize((W, H))); img.alpha_composite(s)

def _top_scrim(img, frac=0.4, strength=165):
    W, H = img.size; g = Image.new("L", (1, H), 0); bot = int(H * frac)
    for y in range(0, bot): g.putpixel((0, y), int(strength * (1 - y / bot)))
    s = Image.new("RGBA", (W, H), (10, 10, 10, 0)); s.putalpha(g.resize((W, H))); img.alpha_composite(s)

def _wrap(d, text, fnt, max_w):
    lines, cur = [], ""
    for w in text.split():
        t = (cur + " " + w).strip()
        if d.textlength(t, font=fnt) > max_w and cur: lines.append(cur); cur = w
        else: cur = t
    if cur: lines.append(cur)
    return lines

def render_all(out_dir, W, H, hook, lower_title, lower_sub, tk, cta=None):
    os.makedirs(out_dir, exist_ok=True)
    white = _hex(tk["colors"]["white"]) + (255,)
    ink = _hex(tk["colors"]["ink"])
    paths = {}

    # logo watermark (top-centre)
    logo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    lw = render_logo(int(W * 0.44), tk, color=white, shadow=True)
    logo.alpha_composite(lw, ((W - lw.width) // 2, int(H * 0.05)))
    logo.save(f"{out_dir}/logo.png"); paths["logo"] = f"{out_dir}/logo.png"

    # hook — Jost display over a top scrim
    hk = Image.new("RGBA", (W, H), (0, 0, 0, 0)); _top_scrim(hk); d = ImageDraw.Draw(hk)
    hf = fit_font("display", max(hook.split(), key=len), W * 0.86, int(W * 0.085), tk)
    y = int(H * 0.135)
    for ln in _wrap(d, hook, hf, W * 0.86):
        tw = d.textlength(ln, font=hf); x = (W - tw) / 2
        d.text((x + 2, y + 2), ln, font=hf, fill=(0, 0, 0, 130)); d.text((x, y), ln, font=hf, fill=white)
        y += int(hf.size * 1.16)
    hk.save(f"{out_dir}/hook.png"); paths["hook"] = f"{out_dir}/hook.png"

    # lower-third — Jost title + DM Sans muted sub over bottom scrim
    lt = Image.new("RGBA", (W, H), (0, 0, 0, 0)); _bottom_scrim(lt); d = ImageDraw.Draw(lt)
    tf = fit_font("display", lower_title, W * 0.9, int(W * 0.062), tk); y = int(H * 0.72)
    tw = d.textlength(lower_title, font=tf)
    d.text(((W - tw) / 2 + 2, y + 2), lower_title, font=tf, fill=(0, 0, 0, 130))
    d.text(((W - tw) / 2, y), lower_title, font=tf, fill=white); y += int(tf.size * 1.15)
    sub = lower_sub.upper(); sf = fit_font("body", sub, W * 0.9, int(W * 0.036), tk, tracking=int(W * 0.006))
    sw = tracked_width(sub, sf, int(W * 0.006)); draw_tracked(d, (W - sw) / 2, y, sub, sf, MUTED, int(W * 0.006))
    lt.save(f"{out_dir}/lower.png"); paths["lower"] = f"{out_dir}/lower.png"

    # end card ("outro") — the site's dark hero: #111 bg, white logo, rounded-full button, url
    ec = Image.new("RGBA", (W, H), ink + (255,)); d = ImageDraw.Draw(ec)
    el = render_logo(int(W * 0.56), tk, color=white, shadow=False)
    ec.alpha_composite(el, ((W - el.width) // 2, int(H * 0.34)))
    ctatext = cta or tk["cta"]
    bf = fit_font("body", ctatext, W * 0.66, int(W * 0.044), tk, tracking=int(W * 0.004))
    bw = tracked_width(ctatext, bf, int(W * 0.004))
    pad_x, pad_y = int(W * 0.06), int(W * 0.035); bh = bf.size + pad_y * 2
    bx0 = (W - (bw + pad_x * 2)) / 2; by0 = int(H * 0.52)
    d.rounded_rectangle([bx0, by0, bx0 + bw + pad_x * 2, by0 + bh], radius=bh / 2, fill=white)  # .btn rounded-full
    draw_tracked(d, bx0 + pad_x, by0 + pad_y, ctatext, bf, ink + (255,), int(W * 0.004))
    uf = font("body", int(W * 0.032), tk); url = tk["url"].upper()
    uw = tracked_width(url, uf, int(W * 0.005)); draw_tracked(d, (W - uw) / 2, int(H * 0.64), url, uf, MUTED, int(W * 0.005))
    ec.save(f"{out_dir}/endcard.png"); paths["endcard"] = f"{out_dir}/endcard.png"
    return paths

if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True); ap.add_argument("--w", type=int, default=1080)
    ap.add_argument("--h", type=int, default=1920); ap.add_argument("--hook", default="")
    ap.add_argument("--title", default=""); ap.add_argument("--sub", default=""); ap.add_argument("--cta", default=None)
    a = ap.parse_args(); tk = load_tokens()
    render_all(a.out, a.w, a.h, a.hook or tk["tagline"], a.title or tk["capitals"],
               a.sub or "Flat-fee residential management", tk, cta=a.cta)
    print("overlays ->", a.out)
