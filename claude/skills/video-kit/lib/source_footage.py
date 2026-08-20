#!/usr/bin/env python3
"""Source free, commercial-licensed stock clips for hero-video assembly.

Providers (free-first): Coverr (no key), Pexels / Pixabay (API key via env or the
sibling .env). `auto` = Pexels if key present, else Pixabay, else Coverr.
Outputs under --out: clips/cNN.mp4, manifest.json, contact_sheet.png.
"""
import argparse, json, os, subprocess, sys, urllib.parse, urllib.request

UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/124 Safari/537.36"
POS = ["home","house","villa","apartment","interior","living","kitchen","bedroom","aerial","drone",
       "skyline","architecture","modern","luxury","pool","garden","suburb","backyard","balcony",
       "residential","neighbourhood","neighborhood","deck","coastal","estate","facade","lounge"]
NEG = ["dance","graffiti","ski","renovation","construction","baby","pregnant","old man","senior",
       "hotel","cleaning","pride","flag","forest","ferry","worker","green screen","bird",
       "monument","monastery","church","farm","agricult","field","dog","protest","war"]

def _load_env():
    p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".env")
    if os.path.exists(p):
        for line in open(p):
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip())

def _get(url, headers=None):
    req = urllib.request.Request(url, headers={"User-Agent": UA, **(headers or {})})
    with urllib.request.urlopen(req, timeout=40) as r:
        return r.read()

def _num(x):
    try: return float(x)
    except Exception: return 0.0

def score(title, tags):
    t = (title + " " + " ".join(tags)).lower()
    return sum(2 for k in POS if k in t) - sum(3 for k in NEG if k in t)

def coverr(query, per_query):
    url = f"https://coverr.co/api/videos?urls=true&page=1&page_size={per_query}&query={urllib.parse.quote(query)}"
    for h in json.loads(_get(url)).get("hits", []):
        if h.get("is_vertical") or h.get("is_premium"): continue
        u = (h.get("urls") or {}).get("mp4")
        if not u: continue
        yield {"title": h.get("title") or "", "url": u, "duration": _num(h.get("duration")),
               "width": h.get("max_width"), "tags": (h.get("tags") or [])[:8],
               "provider": "coverr", "license": "Coverr (commercial, no attribution)"}

def pexels(query, per_query):
    key = os.environ["PEXELS_API_KEY"]
    url = (f"https://api.pexels.com/videos/search?query={urllib.parse.quote(query)}"
           f"&orientation=landscape&size=large&per_page={per_query}")
    for v in json.loads(_get(url, {"Authorization": key})).get("videos", []):
        files = [f for f in v.get("video_files", []) if (f.get("width") or 0) >= 1280 and f.get("link")]
        if not files: continue
        # prefer a file closest to 1920 wide (fast to process, still crisp)
        files.sort(key=lambda f: abs((f.get("width") or 0) - 1920))
        yield {"title": (v.get("url") or "").rstrip("/").split("/")[-1].replace("-", " "),
               "url": files[0]["link"], "duration": _num(v.get("duration")),
               "width": files[0].get("width"), "tags": [], "provider": "pexels",
               "license": "Pexels (commercial, no attribution)"}

def pixabay(query, per_query):
    key = os.environ["PIXABAY_API_KEY"]
    url = f"https://pixabay.com/api/videos/?key={key}&q={urllib.parse.quote(query)}&per_page={per_query}"
    for h in json.loads(_get(url)).get("hits", []):
        vids = h.get("videos") or {}
        f = vids.get("large") or vids.get("medium")
        if not f or not f.get("url"): continue
        yield {"title": h.get("tags") or "", "url": f["url"], "duration": _num(h.get("duration")),
               "width": f.get("width"), "tags": (h.get("tags") or "").split(", ")[:8],
               "provider": "pixabay", "license": "Pixabay (commercial, no attribution)"}

def pick_provider(name):
    if name == "auto":
        if os.environ.get("PEXELS_API_KEY"): return pexels
        if os.environ.get("PIXABAY_API_KEY"): return pixabay
        return coverr
    return {"coverr": coverr, "pexels": pexels, "pixabay": pixabay}[name]

def _contact_sheet(out, n):
    imgd = os.path.join(out, "img"); os.makedirs(imgd, exist_ok=True)
    made = 0
    for i in range(n):
        clip = os.path.join(out, "clips", f"c{i:02d}.mp4")
        if not os.path.exists(clip): continue
        r = subprocess.run(["ffmpeg","-y","-ss","2","-i",clip,"-frames:v","1","-vf",
            "scale=480:270:force_original_aspect_ratio=decrease,pad=480:270:(ow-iw)/2:(oh-ih)/2:color=0x1a1a1a",
            os.path.join(imgd, f"f{i:02d}.jpg")], capture_output=True)
        made += (r.returncode == 0)
    cols = 6
    subprocess.run(["ffmpeg","-y","-f","image2","-pattern_type","glob","-i",
        os.path.join(imgd,"f*.jpg"),"-vf", f"tile={cols}x{(made+cols-1)//cols}",
        os.path.join(out,"contact_sheet.png")], capture_output=True)

def main():
    _load_env()
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--queries", required=True, help="comma-separated")
    ap.add_argument("--provider", default="auto")
    ap.add_argument("--max", type=int, default=18)
    ap.add_argument("--per-query", type=int, default=12)
    ap.add_argument("--min-duration", type=float, default=5.0)
    a = ap.parse_args()
    fetch = pick_provider(a.provider)
    os.makedirs(os.path.join(a.out, "clips"), exist_ok=True)
    seen, cands = set(), []
    for q in [q.strip() for q in a.queries.split(",") if q.strip()]:
        try: items = list(fetch(q, a.per_query))
        except Exception as e: print(f"  ! {q}: {e}", file=sys.stderr); continue
        for it in items:
            if it["url"] in seen or it["duration"] < a.min_duration: continue
            seen.add(it["url"]); it["score"] = score(it["title"], it["tags"]); cands.append(it)
    cands.sort(key=lambda c: (-c["score"], -c["duration"]))
    cands = cands[:a.max]
    manifest = []
    for i, c in enumerate(cands):
        dst = os.path.join(a.out, "clips", f"c{i:02d}.mp4")
        try:
            with open(dst, "wb") as fh: fh.write(_get(c["url"]))
        except Exception as e:
            print(f"  ! download {i}: {e}", file=sys.stderr); continue
        c["index"] = i; manifest.append(c)
        print(f"  {i:02d} | score {c['score']:>2} | {c['duration']:>4.1f}s | {c['provider']:6} | {c['title'][:44]}")
    json.dump(manifest, open(os.path.join(a.out, "manifest.json"), "w"), indent=2)
    _contact_sheet(a.out, len(cands))
    print(f"downloaded {len(manifest)} clips + contact_sheet.png -> {a.out}")

if __name__ == "__main__":
    main()
