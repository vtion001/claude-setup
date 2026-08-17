#!/usr/bin/env python3
"""Assemble a cinematic hero-background variant from normalized clips.

Applies the pro real-estate-video playbook: hero shot first (caller orders the
clips), slow-smooth holds, a warm residential grade, and subtle crossfades only
(no flashy effects). Output: landscape H.264, muted, +faststart.
"""
import argparse, subprocess, sys, os

# Warm, natural residential grade (comfort/luxury). Kept subtle on purpose —
# over-grading is the #1 amateur tell. eq lifts contrast/saturation gently;
# colorbalance warms mids+highlights (more red, less blue).
DEFAULT_GRADE = ("eq=contrast=1.06:saturation=1.07:gamma=1.02,"
                 "colorbalance=rm=0.04:bm=-0.03:rh=0.05:bh=-0.05")

def dur(f):
    out = subprocess.run(["ffprobe","-v","error","-show_entries","format=duration","-of","csv=p=0",f],
                         capture_output=True, text=True).stdout.strip()
    try: return float(out)
    except Exception: return 6.0

def build(clips_dir, order, out, seglen=5.6, tr=0.9, W=1920, H=1080, grade=DEFAULT_GRADE):
    inputs, filt = [], []
    for idx, ci in enumerate(order):
        f = os.path.join(clips_dir, f"c{ci:02d}.mp4")
        if not os.path.exists(f):                       # source_footage nests under clips/
            alt = os.path.join(clips_dir, "clips", f"c{ci:02d}.mp4")
            if os.path.exists(alt): f = alt
        d = dur(f)
        ss = min(max(d*0.25, 0.0), max(0.0, d - seglen - 0.1))   # stable mid-section
        inputs += ["-ss", f"{ss:.2f}", "-t", f"{seglen:.2f}", "-i", f]
        filt.append(
            f"[{idx}:v]scale={W}:{H}:force_original_aspect_ratio=increase,crop={W}:{H},"
            f"fps=30,setsar=1,setpts=PTS-STARTPTS,{grade},format=yuv420p[v{idx}]")
    prev, cum = "v0", seglen
    for i in range(1, len(order)):
        filt.append(f"[{prev}][v{i}]xfade=transition=fade:duration={tr}:offset={cum-tr:.2f}[x{i}]")
        prev = f"x{i}"; cum += seglen - tr
    # subtle vignette for focus + fade in/out for a clean hero loop
    filt.append(f"[{prev}]vignette=PI/4.5,fade=t=in:st=0:d=1.0,fade=t=out:st={cum-1.0:.2f}:d=1.0[out]")
    cmd = ["ffmpeg","-y"] + inputs + ["-filter_complex", ";".join(filt), "-map","[out]","-an",
           "-c:v","libx264","-profile:v","high","-pix_fmt","yuv420p","-r","30","-crf","20",
           "-preset","slow","-movflags","+faststart", out]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stderr[-2000:], file=sys.stderr); sys.exit(1)
    print(f"{out}: OK (~{cum:.1f}s)")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--clips-dir", required=True)
    ap.add_argument("--order", required=True, help="comma-separated clip indices, hero first")
    ap.add_argument("--out", required=True)
    ap.add_argument("--seglen", type=float, default=5.6)
    ap.add_argument("--xfade", type=float, default=0.9)
    ap.add_argument("--width", type=int, default=1920)
    ap.add_argument("--height", type=int, default=1080)
    ap.add_argument("--grade", default=DEFAULT_GRADE, help="ffmpeg filter chain for the look")
    a = ap.parse_args()
    build(a.clips_dir, [int(x) for x in a.order.split(",")], a.out,
          a.seglen, a.xfade, a.width, a.height, a.grade)

if __name__ == "__main__":
    main()
