// One-time asset generator: rasterizes an existing SVG/PNG source into the
// multi-resolution build/icon.ico (Windows) AND build/icon.icns (macOS) both
// platforms need — same script, works from either host OS (pure JS, no
// native platform tool dependency), so run it once regardless of which
// platform you're building on. Output is a checked-in build asset, not
// regenerated on every build — re-run only when the source icon changes.
//
// Usage: node make-icon.mjs <source.svg|source.png> <output-dir>
import sharp from "sharp";
import toIco from "to-ico";
import png2icons from "png2icons";
import { readFile, writeFile, mkdir } from "node:fs/promises";
import path from "node:path";

const [, , sourcePath, outDir = "build"] = process.argv;
if (!sourcePath) {
  console.error("Usage: node make-icon.mjs <source.svg|source.png> <output-dir>");
  process.exit(1);
}

const ICO_SIZES = [16, 32, 48, 256];
const ICNS_SIZE = 1024; // png2icons derives every size macOS needs from one large source

const source = await readFile(sourcePath);

// .ico: a handful of exact raster sizes combined into one file.
const pngs = await Promise.all(
  ICO_SIZES.map((size) => sharp(source, { density: 384 }).resize(size, size).png().toBuffer()),
);
const ico = await toIco(pngs);

// .icns: png2icons wants one large PNG and derives the size set itself.
const largePng = await sharp(source, { density: 384 }).resize(ICNS_SIZE, ICNS_SIZE).png().toBuffer();
const icns = png2icons.createICNS(largePng, png2icons.BILINEAR, 0);
if (!icns) {
  throw new Error("png2icons failed to produce an .icns — check the source image is square and readable");
}

await mkdir(outDir, { recursive: true });
await writeFile(path.join(outDir, "icon.ico"), ico);
await writeFile(path.join(outDir, "icon.icns"), icns);
console.log(`wrote ${outDir}/icon.ico (${ICO_SIZES.join(", ")}px) and ${outDir}/icon.icns`);
