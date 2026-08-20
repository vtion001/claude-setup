#!/usr/bin/env python3
"""Turn the user's own photos into Ken Burns clips the video builders can use.

Each image -> a slow pan/zoom clip (alternating zoom-in / zoom-out for variety),
filled to the target WxH, 30fps, muted. Output: <out>/clips/cNN.mp4 (index =
input order) + a contact_sheet.png, matching source_footage.py's layout so
reel.py / assemble.py consume it identically.
"""
import argparse, glob, os, subprocess, sys

EXTS = (".jpg", ".jpeg", ".png", ".webp", ".heic", ".tif", ".tiff")

def ken_burns(img, out, W, H, sec, zoom_in=True):
    frames = int(sec * 30)
    OW, OH = int(W * 1.4), int(H * 1.4)  # modest oversample: smooth zoom, fast render
    if zoom_in:
        z = "min(zoom+0.0011,1.18)"
    else:  # start zoomed, ease out
        z = "if(eq(on,0),1.18,max(zoom-0.0011,1.0))"
    # d=1 => one output frame per (looped) input frame; -t bounds the total; zoom
    # animates via the running `zoom`/`on`. (d=frames here would explode the graph.)
    vf = (f"scale={OW}:{OH}:force_original_aspect_ratio=increase,crop={OW}:{OH},"
          f"zoompan=z='{z}':d=1:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':"
          f"s={W}x{H}:fps=30,format=yuv420p")
    r = subprocess.run(["ffmpeg","-y","-loop","1","-framerate","30","-t",f"{sec}","-i",img,
                        "-vf",vf,"-c:v","libx264","-crf","20","-preset","veryfast","-an",out],
                       capture_output=True, text=True)
    if r.returncode != 0:
        print(f"  ! {os.path.basename(img)}: {r.stderr[-500:]}", file=sys.stderr); return False
    return True

def contact_sheet(out, n):
    imgd = os.path.join(out, "img"); os.makedirs(imgd, exist_ok=True)
    for i in range(n):
        clip = os.path.join(out, "clips", f"c{i:02d}.mp4")
        if os.path.exists(clip):
            subprocess.run(["ffmpeg","-y","-ss","1","-i",clip,"-frames:v","1","-vf",
                "scale=480:270:force_original_aspect_ratio=decrease,pad=480:270:(ow-iw)/2:(oh-ih)/2:color=0x1a1a1a",
                os.path.join(imgd, f"f{i:02d}.jpg")], capture_output=True)
    subprocess.run(["ffmpeg","-y","-f","image2","-pattern_type","glob","-i",os.path.join(imgd,"f*.jpg"),
        "-vf", f"tile=6x{(n+5)//6}", os.path.join(out,"contact_sheet.png")], capture_output=True)

def collect(paths):
    files = []
    for p in paths:
        if os.path.isdir(p):
            files += sorted(f for f in glob.glob(os.path.join(p, "*")) if f.lower().endswith(EXTS))
        elif p.lower().endswith(EXTS) and os.path.exists(p):
            files.append(p)
    return files

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--photos", nargs="+", required=True, help="image files and/or directories, in order")
    ap.add_argument("--width", type=int, default=1920)
    ap.add_argument("--height", type=int, default=1080)
    ap.add_argument("--seconds", type=float, default=6.0)
    a = ap.parse_args()
    imgs = collect(a.photos)
    if not imgs:
        print("no images found", file=sys.stderr); sys.exit(1)
    os.makedirs(os.path.join(a.out, "clips"), exist_ok=True)
    made = 0
    for i, img in enumerate(imgs):
        dst = os.path.join(a.out, "clips", f"c{i:02d}.mp4")
        if ken_burns(img, dst, a.width, a.height, a.seconds, zoom_in=(i % 2 == 0)):
            made += 1; print(f"  c{i:02d} <- {os.path.basename(img)}")
    contact_sheet(a.out, len(imgs))
    print(f"built {made}/{len(imgs)} Ken Burns clips + contact_sheet.png -> {a.out} ({a.width}x{a.height})")

if __name__ == "__main__":
    main()
