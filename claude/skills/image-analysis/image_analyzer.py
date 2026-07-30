#!/usr/bin/env python3
"""
Enhanced Image Analysis Tool for OpenCode
Analyzes screenshots with improved OCR accuracy

Usage:
    python3 image_analyzer.py <image_path> [--verbose] [--save-report]
    python3 image_analyzer.py --interactive
"""

import sys
import os
import argparse
from PIL import Image, ImageEnhance, ImageFilter, ImageOps, ImageStat
import numpy as np
import pytesseract


class EnhancedImageAnalyzer:
    def __init__(self, image_path):
        self.image_path = image_path
        self.img = None
        self.width = 0
        self.height = 0
        self.results = {}

    def load_image(self):
        """Load and validate image"""
        if not os.path.exists(self.image_path):
            raise FileNotFoundError(f"Image not found: {self.image_path}")
        self.img = Image.open(self.image_path)
        self.width, self.height = self.img.size
        return self

    def preprocess_basic(self):
        """Basic preprocessing for OCR"""
        img = self.img.convert("L")
        enhancer = ImageEnhance.Contrast(img)
        img = enhancer.enhance(2.0)
        return img

    def preprocess_aggressive(self):
        """Aggressive preprocessing for difficult images"""
        # Convert to grayscale
        img = self.img.convert("L")

        # Increase contrast significantly
        enhancer = ImageEnhance.Contrast(img)
        img = enhancer.enhance(3.0)

        # Apply sharpening
        img = img.filter(ImageFilter.SHARPEN)

        # Threshold to create high contrast binary
        img_array = np.array(img)
        # Use Otsu's method approximation
        threshold = np.mean(img_array) + np.std(img_array)
        img_binary = ((img_array > threshold) * 255).astype(np.uint8)

        return Image.fromarray(img_binary)

    def preprocess_denoised(self):
        """Preprocessing with denoising"""
        # Convert to numpy
        img_array = np.array(self.img.convert("RGB"))

        # Simple denoising (moving average)
        denoised = np.zeros_like(img_array)
        kernel_size = 3
        for c in range(3):
            for i in range(kernel_size, img_array.shape[0] - kernel_size):
                for j in range(kernel_size, img_array.shape[1] - kernel_size):
                    denoised[i, j, c] = np.mean(
                        img_array[
                            i - kernel_size : i + kernel_size + 1,
                            j - kernel_size : j + kernel_size + 1,
                            c,
                        ]
                    )

        img = Image.fromarray(denoised.astype(np.uint8))

        # Convert to grayscale and enhance
        img = img.convert("L")
        enhancer = ImageEnhance.Contrast(img)
        img = enhancer.enhance(2.5)

        return img

    def preprocess_upscale(self):
        """Preprocessing with upscaling 2x"""
        # Upscale with LANCZOS
        img = self.img.resize((self.width * 2, self.height * 2), Image.LANCZOS)

        # Convert to grayscale and enhance
        img = img.convert("L")
        enhancer = ImageEnhance.Contrast(img)
        img = enhancer.enhance(2.0)

        # Sharpen
        img = img.filter(ImageFilter.SHARPEN)

        return img

    def extract_text(self, img, config="--psm 6"):
        """Extract text using tesseract"""
        try:
            return pytesseract.image_to_string(img, config=f"{config} -l eng")
        except Exception as e:
            return f"Error: {e}"

    def extract_with_boxes(self, img, config="--psm 6"):
        """Extract text with bounding box data"""
        try:
            return pytesseract.image_to_data(
                img, config=f"{config} -l eng", output_type=pytesseract.Output.DICT
            )
        except Exception as e:
            return {
                "text": [],
                "conf": [],
                "left": [],
                "top": [],
                "width": [],
                "height": [],
            }

    def analyze_layout(self, img):
        """Analyze layout by regions"""
        width, height = self.width, self.height

        regions = {
            "header": (0, int(height * 0.12)),
            "hero": (int(height * 0.12), int(height * 0.40)),
            "content": (int(height * 0.40), int(height * 0.70)),
            "cta": (int(height * 0.70), int(height * 0.85)),
            "footer": (int(height * 0.85), height),
        }

        layout_results = {}
        for name, (y1, y2) in regions.items():
            region = img.crop((0, y1, width, y2))
            text = self.extract_text(region)
            layout_results[name] = {
                "text": text.strip() if text else "(no text)",
                "size": f"{width}x{y2 - y1}",
            }

        return layout_results

    def analyze_colors(self):
        """Analyze color distribution"""
        arr = np.array(self.img.convert("RGB"))
        width, height = self.width, self.height

        brand_colors = {
            "navy (#0B2D4E)": {"rgb": (11, 45, 78), "tolerance": 30, "count": 0},
            "teal (#199B93)": {"rgb": (25, 155, 147), "tolerance": 30, "count": 0},
            "white (#FFFFFF)": {"rgb": (255, 255, 255), "tolerance": 30, "count": 0},
            "gray-100 (#F3F4F6)": {"rgb": (243, 244, 246), "tolerance": 20, "count": 0},
            "gray-900 (#111827)": {"rgb": (17, 24, 39), "tolerance": 30, "count": 0},
        }

        for name, data in brand_colors.items():
            r, g, b = data["rgb"]
            tol = data["tolerance"]
            mask = np.all(
                (
                    np.abs(arr[:, :, 0] - r) < tol,
                    np.abs(arr[:, :, 1] - g) < tol,
                    np.abs(arr[:, :, 2] - b) < tol,
                ),
                axis=0,
            )
            data["count"] = int(np.sum(mask))
            data["percentage"] = round(data["count"] / (width * height) * 100, 2)

        return brand_colors

    def analyze_word_positions(self, data, min_word_length=3):
        """Extract word positions from tesseract data"""
        words = []
        for i, word in enumerate(data["text"]):
            if word.strip() and len(word) >= min_word_length:
                x, y = data["left"][i], data["top"][i]
                w, h = data["width"][i], data["height"][i]
                if w > 15 and h > 5 and data["conf"][i] > 30:  # Filter low confidence
                    words.append(
                        {
                            "word": word,
                            "x_pct": round(x / self.width * 100, 1),
                            "y_pct": round(y / self.height * 100, 1),
                            "w_pct": round(w / self.width * 100, 1),
                            "h_pct": round(h / self.height * 100, 1),
                            "confidence": data["conf"][i],
                        }
                    )
        return words

    def run_full_analysis(self, verbose=False):
        """Run complete analysis"""
        self.load_image()

        if verbose:
            print(f"Image: {self.image_path}")
            print(f"Size: {self.width}x{self.height}")
            print("-" * 50)

        results = {
            "image_info": {
                "path": self.image_path,
                "width": self.width,
                "height": self.height,
            },
            "colors": {},
            "text": {},
            "layout": {},
            "words": [],
        }

        # Try multiple preprocessing methods
        preprocessing_methods = [
            ("basic", self.preprocess_basic),
            ("aggressive", self.preprocess_aggressive),
            ("upscale", self.preprocess_upscale),
        ]

        best_text = ""
        best_confidence = 0

        for name, preprocess_fn in preprocessing_methods:
            processed = preprocess_fn()
            text = self.extract_text(processed)
            data = self.extract_with_boxes(processed)

            # Calculate average confidence
            conf_values = [c for c in data["conf"] if c > 0]
            avg_conf = sum(conf_values) / len(conf_values) if conf_values else 0

            results["text"][name] = {"text": text, "avg_confidence": round(avg_conf, 1)}

            if avg_conf > best_confidence:
                best_confidence = avg_conf
                best_text = text
                results["words"] = self.analyze_word_positions(data)

        # Use the best result
        results["text"]["best"] = {"text": best_text, "avg_confidence": best_confidence}

        # Layout analysis
        processed = self.preprocess_basic()
        results["layout"] = self.analyze_layout(processed)

        # Color analysis
        results["colors"] = self.analyze_colors()

        self.results = results
        return results

    def print_report(self):
        """Print formatted analysis report"""
        if not self.results:
            print("No analysis results. Run run_full_analysis() first.")
            return

        r = self.results

        print("=" * 60)
        print("ENHANCED IMAGE ANALYSIS REPORT")
        print("=" * 60)

        print(f"\n📷 IMAGE INFO")
        print(f"   Path: {r['image_info']['path']}")
        print(f"   Size: {r['image_info']['width']}x{r['image_info']['height']}")

        print(f"\n🎨 COLOR ANALYSIS")
        for name, data in r["colors"].items():
            pct = data["percentage"]
            bar = "█" * int(pct / 2)
            print(f"   {name}: {pct:5.1f}% {bar}")

        print(f"\n📝 TEXT EXTRACTION (Best Method)")
        best = r["text"]["best"]
        print(f"   Confidence: {best['avg_confidence']}%")
        print(f"\n   Text Content:")
        for line in best["text"].split("\n")[:30]:
            if line.strip():
                print(f"      {line}")

        print(f"\n📐 LAYOUT ANALYSIS")
        for region, data in r["layout"].items():
            print(f"\n   [{region.upper()}] ({data['size']})")
            text_preview = data["text"][:100].replace("\n", " ")
            print(f"   {text_preview}...")

        print(f"\n📍 KEY WORD POSITIONS")
        print(f"   (showing first 25 words by position)")
        for w in sorted(r["words"], key=lambda x: (x["y_pct"], x["x_pct"]))[:25]:
            print(
                f"   '{w['word']}' at ({w['x_pct']}%, {w['y_pct']}%) conf:{w['confidence']}"
            )

        print("\n" + "=" * 60)

    def save_report(self, output_path=None):
        """Save report to file"""
        if not self.results:
            return

        if not output_path:
            output_path = self.image_path + "_analysis.txt"

        with open(output_path, "w") as f:
            r = self.results

            f.write("=" * 60 + "\n")
            f.write("ENHANCED IMAGE ANALYSIS REPORT\n")
            f.write("=" * 60 + "\n\n")

            f.write(f"IMAGE INFO\n")
            f.write(f"  Path: {r['image_info']['path']}\n")
            f.write(
                f"  Size: {r['image_info']['width']}x{r['image_info']['height']}\n\n"
            )

            f.write(f"COLOR ANALYSIS\n")
            for name, data in r["colors"].items():
                f.write(f"  {name}: {data['percentage']}%\n")
            f.write("\n")

            f.write(f"TEXT EXTRACTION\n")
            for name, data in r["text"].items():
                f.write(f"\n  [{name}] Confidence: {data['avg_confidence']}%\n")
                f.write(f"  {data['text'][:1000]}\n\n")

            f.write(f"LAYOUT ANALYSIS\n")
            for region, data in r["layout"].items():
                f.write(f"\n  [{region}]\n")
                f.write(f"  {data['text'][:500]}\n")

            f.write(f"\nWORD POSITIONS\n")
            for w in r["words"][:50]:
                f.write(f"  '{w['word']}' at ({w['x_pct']}%, {w['y_pct']}%)\n")

        return output_path


def main():
    parser = argparse.ArgumentParser(description="Enhanced Image Analysis Tool")
    parser.add_argument("image_path", nargs="?", help="Path to image file")
    parser.add_argument(
        "--interactive", "-i", action="store_true", help="Interactive mode"
    )
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    parser.add_argument("--save", "-s", action="store_true", help="Save report to file")

    args = parser.parse_args()

    if args.interactive:
        # Interactive mode - list screenshots
        desktop = os.path.expanduser("~/Desktop")
        files = [f for f in os.listdir(desktop) if f.startswith("Screenshot")]
        print("Available screenshots on Desktop:")
        for i, f in enumerate(sorted(files), 1):
            print(f"  {i}. {f}")

        choice = input("\nEnter number or path: ").strip()
        if choice.isdigit() and 1 <= int(choice) <= len(files):
            image_path = os.path.join(desktop, sorted(files)[int(choice) - 1])
        else:
            image_path = choice
    elif args.image_path:
        image_path = args.image_path
    else:
        # Try to find a screenshot
        desktop = os.path.expanduser("~/Desktop")
        files = [f for f in os.listdir(desktop) if f.startswith("Screenshot")]
        if files:
            # Get most recent
            files_sorted = sorted(
                files,
                key=lambda x: os.path.getmtime(os.path.join(desktop, x)),
                reverse=True,
            )
            image_path = os.path.join(desktop, files_sorted[0])
            print(f"Using most recent screenshot: {files_sorted[0]}")
        else:
            print("Error: No image path provided and no screenshots found")
            print("Usage: python3 image_analyzer.py <image_path>")
            sys.exit(1)

    # Run analysis
    analyzer = EnhancedImageAnalyzer(image_path)
    analyzer.run_full_analysis(verbose=args.verbose)
    analyzer.print_report()

    if args.save:
        output_path = analyzer.save_report()
        print(f"\n📄 Report saved to: {output_path}")


if __name__ == "__main__":
    main()
