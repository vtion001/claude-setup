#!/usr/bin/env python3
"""Build an A4 PDF from JPEG scans, honouring EXIF orientation. usage: jpg2pdf.py OUT.pdf IN.jpg..."""
import math
import sys

import Quartz
from CoreFoundation import CFURLCreateWithFileSystemPath, kCFAllocatorDefault

A4_W, A4_H = 595.276, 841.89
MARGIN = 18.0

out, images = sys.argv[1], sys.argv[2:]
url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, out, 0, False)
ctx = Quartz.CGPDFContextCreateWithURL(url, Quartz.CGRectMake(0, 0, A4_W, A4_H), None)

for path in images:
    src = Quartz.CGImageSourceCreateWithURL(
        CFURLCreateWithFileSystemPath(kCFAllocatorDefault, path, 0, False), None)
    img = Quartz.CGImageSourceCreateImageAtIndex(src, 0, None)
    orient = Quartz.CGImageSourceCopyPropertiesAtIndex(src, 0, None).get("Orientation", 1)
    iw, ih = Quartz.CGImageGetWidth(img), Quartz.CGImageGetHeight(img)
    # displayed dimensions after applying the EXIF rotation
    dw, dh = (ih, iw) if orient in (5, 6, 7, 8) else (iw, ih)

    avail_w, avail_h = A4_W - 2 * MARGIN, A4_H - 2 * MARGIN
    scale = min(avail_w / dw, avail_h / dh)
    fw, fh = dw * scale, dh * scale
    x, y = (A4_W - fw) / 2, (A4_H - fh) / 2

    Quartz.CGContextBeginPage(ctx, None)
    Quartz.CGContextSaveGState(ctx)
    Quartz.CGContextTranslateCTM(ctx, x, y)
    if orient == 6:      # rotate 90 clockwise
        Quartz.CGContextTranslateCTM(ctx, 0, fh)
        Quartz.CGContextRotateCTM(ctx, -math.pi / 2)
        Quartz.CGContextDrawImage(ctx, Quartz.CGRectMake(0, 0, fh, fw), img)
    elif orient == 8:    # rotate 90 counter-clockwise
        Quartz.CGContextTranslateCTM(ctx, fw, 0)
        Quartz.CGContextRotateCTM(ctx, math.pi / 2)
        Quartz.CGContextDrawImage(ctx, Quartz.CGRectMake(0, 0, fh, fw), img)
    elif orient == 3:    # 180
        Quartz.CGContextTranslateCTM(ctx, fw, fh)
        Quartz.CGContextRotateCTM(ctx, math.pi)
        Quartz.CGContextDrawImage(ctx, Quartz.CGRectMake(0, 0, fw, fh), img)
    else:
        Quartz.CGContextDrawImage(ctx, Quartz.CGRectMake(0, 0, fw, fh), img)
    Quartz.CGContextRestoreGState(ctx)
    Quartz.CGContextEndPage(ctx)

Quartz.CGPDFContextClose(ctx)
print(f"wrote {out} ({len(images)} pages)")
