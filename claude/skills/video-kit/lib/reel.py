#!/usr/bin/env python3
"""Build a branded vertical (9:16) marketing reel from footage clips.

Pipeline (staged for robustness): clips -> 9:16 blurred-pad graded segments ->
xfade concat -> logo/hook/lower-third overlays (Pillow PNGs, alpha-faded) ->
appended navy end card -> Mixkit music bed -> final.mp4 (+ .srt sidecar).
This ffmpeg has no drawtext, so all text is Pillow-rendered PNG overlays.
"""
import argparse, os, subprocess, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import brand

GRADE = ("eq=contrast=1.06:saturation=1.07:gamma=1.02,"
         "colorbalance=rm=0.04:bm=-0.03:rh=0.05:bh=-0.05")

def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(" ".join(cmd[:6]), "...\n", r.stderr[-1600:], file=sys.stderr); sys.exit(1)
    return r

def dur(f):
    o = subprocess.run(["ffprobe","-v","error","-show_entries","format=duration","-of","csv=p=0",f],
                       capture_output=True, text=True).stdout.strip()
    try: return float(o)
    except Exception: return 6.0

def clip_path(clips_dir, ci):
    f = os.path.join(clips_dir, f"c{ci:02d}.mp4")
    if not os.path.exists(f):
        alt = os.path.join(clips_dir, "clips", f"c{ci:02d}.mp4")
        if os.path.exists(alt): return alt
    return f

def _srt_time(t):
    ms = int((t - int(t)) * 1000); s = int(t) % 60; m = (int(t)//60) % 60; h = int(t)//3600
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"

def seg_filter(fill, W, H):
    """Stage-A filtergraph. fill='blurpad' keeps the whole frame over a blurred
    background (skylines intact); fill='crop' is full-bleed center-crop (immersive,
    but trims the sides of 16:9 footage)."""
    if fill == "crop":
        return (f"[0:v]scale={W}:{H}:force_original_aspect_ratio=increase,crop={W}:{H},"
                f"fps=30,setsar=1,setpts=PTS-STARTPTS,{GRADE},format=yuv420p[v]")
    return (f"[0:v]split=2[fg][b];[b]scale={W}:{H}:force_original_aspect_ratio=increase,"
            f"crop={W}:{H},scale=150:-2,scale={W}:{H},eq=brightness=-0.12:saturation=0.9[bg];"
            f"[fg]scale={W}:-2:force_original_aspect_ratio=decrease[fs];"
            f"[bg][fs]overlay=(W-w)/2:(H-h)/2,fps=30,setsar=1,{GRADE},format=yuv420p[v]")

def build(clips_dir, order, out, hook, title, sub, music=None, W=1080, H=1920,
          seglen=4.8, tr=0.6, endcard_dur=3.5, fill="blurpad", cta=None, tk=None):
    tk = tk or brand.load_tokens()
    work = tempfile.mkdtemp(prefix="reel_")
    ov = brand.render_all(os.path.join(work, "ov"), W, H, hook, title, sub, tk, cta=cta)

    # Stage A — 9:16 graded segments (blurpad or full-bleed crop)
    segs = []
    for i, ci in enumerate(order):
        f = clip_path(clips_dir, ci); d = dur(f)
        ss = min(max(d*0.25, 0.0), max(0.0, d - seglen - 0.1))
        seg = os.path.join(work, f"seg{i}.mp4"); segs.append(seg)
        run(["ffmpeg","-y","-ss",f"{ss:.2f}","-t",f"{seglen:.2f}","-i",f,
             "-filter_complex", seg_filter(fill, W, H),
             "-map","[v]","-an","-c:v","libx264","-crf","20","-preset","veryfast", seg])

    # Stage B — xfade the footage segments
    footbase = os.path.join(work, "footbase.mp4")
    if len(segs) == 1:
        footbase = segs[0]; footdur = seglen
    else:
        inp, filt, prev, cum = [], [], "0:v", seglen
        for s in segs: inp += ["-i", s]
        for i in range(1, len(segs)):
            filt.append(f"[{prev}][{i}:v]xfade=transition=fade:duration={tr}:offset={cum-tr:.2f}[x{i}]")
            prev = f"x{i}"; cum += seglen - tr
        footdur = cum
        run(["ffmpeg","-y"]+inp+["-filter_complex",";".join(filt),"-map",f"[{prev}]","-an",
             "-c:v","libx264","-crf","20","-preset","veryfast", footbase])

    # Stage C — overlays (logo persistent; hook + lower-third timed, alpha-faded)
    lt0, lt1 = min(5.4, footdur*0.32), min(10.4, footdur*0.62)
    branded = os.path.join(work, "branded.mp4")
    _t = f"{footdur + 0.5:.2f}"   # bound the looped PNGs (unbounded -loop 1 hangs the graph)
    run(["ffmpeg","-y","-i",footbase,
         "-loop","1","-framerate","30","-t",_t,"-i",ov["logo"],
         "-loop","1","-framerate","30","-t",_t,"-i",ov["hook"],
         "-loop","1","-framerate","30","-t",_t,"-i",ov["lower"],
         "-filter_complex",
         "[1]format=rgba,fade=t=in:st=0.5:d=0.6:alpha=1[lg];[0:v][lg]overlay=0:0:shortest=1[a];"
         "[2]format=rgba,fade=t=in:st=0.4:d=0.4:alpha=1,fade=t=out:st=3.0:d=0.5:alpha=1[hk];"
         "[a][hk]overlay=0:0:enable='between(t,0.3,3.6)'[b];"
         f"[3]format=rgba,fade=t=in:st={lt0:.2f}:d=0.5:alpha=1,fade=t=out:st={lt1-0.5:.2f}:d=0.5:alpha=1[lw];"
         f"[b][lw]overlay=0:0:enable='between(t,{lt0:.2f},{lt1:.2f})'[out]",
         "-map","[out]","-an","-c:v","libx264","-crf","20","-preset","veryfast", branded])

    # Stage D — end card clip
    endc = os.path.join(work, "endcard.mp4")
    run(["ffmpeg","-y","-loop","1","-t",f"{endcard_dur}","-framerate","30","-i",ov["endcard"],
         "-vf","fps=30,format=yuv420p,fade=t=in:st=0:d=0.5","-an",
         "-c:v","libx264","-crf","20","-preset","veryfast", endc])

    # Stage E — xfade footage(branded) -> end card
    silent = os.path.join(work, "silent.mp4")
    off = footdur - tr
    run(["ffmpeg","-y","-i",branded,"-i",endc,"-filter_complex",
         f"[0:v][1:v]xfade=transition=fade:duration={tr}:offset={off:.2f}[out]",
         "-map","[out]","-an","-c:v","libx264","-crf","20","-preset","veryfast", silent])
    total = footdur + endcard_dur - tr

    # Stage F — music bed (or silent passthrough)
    if music and os.path.exists(music):
        run(["ffmpeg","-y","-i",silent,"-i",music,"-filter_complex",
             f"[1:a]afade=t=in:st=0:d=1.2,afade=t=out:st={max(0,total-2):.2f}:d=2,volume=0.55[a]",
             "-map","0:v","-map","[a]","-c:v","copy","-c:a","aac","-b:a","192k","-shortest",
             "-movflags","+faststart", out])
    else:
        run(["ffmpeg","-y","-i",silent,"-an","-c:v","copy","-movflags","+faststart", out])

    # .srt sidecar (spoken-caption friendly for platform upload)
    srt = os.path.splitext(out)[0] + ".srt"
    with open(srt, "w") as fh:
        fh.write(f"1\n{_srt_time(0.3)} --> {_srt_time(3.3)}\n{hook}\n\n")
        fh.write(f"2\n{_srt_time(lt0)} --> {_srt_time(lt1)}\n{title} — {sub}\n\n")
        fh.write(f"3\n{_srt_time(total-endcard_dur+0.3)} --> {_srt_time(total)}\n{tk['cta']} · {tk['url']}\n")
    print(f"{out}: OK (~{total:.1f}s, {W}x{H}) + {os.path.basename(srt)}")
    return total

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--clips-dir", required=True)
    ap.add_argument("--order", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--hook", default=None)
    ap.add_argument("--title", default=None)
    ap.add_argument("--sub", default="Flat-fee residential management")
    ap.add_argument("--music", default=None)
    ap.add_argument("--width", type=int, default=1080)
    ap.add_argument("--height", type=int, default=1920)
    ap.add_argument("--seglen", type=float, default=4.8)
    ap.add_argument("--fill", choices=["blurpad", "crop"], default="blurpad",
                    help="blurpad = whole frame over blurred bg (skylines intact); crop = full-bleed")
    ap.add_argument("--cta", default=None, help="end-card call-to-action (default from brand_tokens)")
    a = ap.parse_args()
    tk = brand.load_tokens()
    build(a.clips_dir, [int(x) for x in a.order.split(",")], a.out,
          a.hook or tk["tagline"], a.title or tk["capitals"], a.sub,
          a.music, a.width, a.height, a.seglen, fill=a.fill, cta=a.cta, tk=tk)

if __name__ == "__main__":
    main()
