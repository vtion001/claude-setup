#!/usr/bin/env python3
"""
Vision OCR Tool - Uses macOS Vision framework for accurate OCR
Much better accuracy than Tesseract for most use cases

Usage:
    python3 vision_ocr.py <image_path>
    python3 vision_ocr.py --interactive
"""

import os
import sys
import argparse
from PIL import Image
import Vision
import numpy as np


class VisionOCR:
    def __init__(self, image_path):
        self.image_path = image_path
        self.img = Image.open(image_path)

    def recognize_text(self):
        """Use Vision framework to recognize text"""
        # Convert PIL Image to CGImage
        cg_image = self.img.convert("RGBA")._im

        # Create Vision request
        request = Vision.VNRecognizeTextRequest.alloc().init()
        request.setRecognitionLevel_(Vision.VNRequestTextRecognitionLevel.accurate)
        request.setRecognitionLanguages_(["en-US"])

        # Perform request
        handler = Vision.VNImageRequestHandler.alloc().initWithCGImage_options_(
            cg_image, None
        )
        handler.performRequests_([request], error=None)

        # Get results
        results = []
        if request.results():
            for observation in request.results():
                text = observation.topCandidates_(1)[0]
                results.append(
                    {
                        "text": text[0].string(),
                        "confidence": text[0].confidence(),
                        "bounding_box": {
                            "x": observation.boundingBox().origin.x,
                            "y": observation.boundingBox().origin.y,
                            "width": observation.boundingBox().size.width,
                            "height": observation.boundingBox().size.height,
                        },
                    }
                )

        return results

    def get_full_text(self):
        """Get all recognized text as a single string"""
        results = self.recognize_text()
        return "\n".join([r["text"] for r in results])

    def print_results(self):
        """Print formatted results"""
        results = self.recognize_text()

        if not results:
            print("No text recognized")
            return

        print(f"Recognized {len(results)} text elements:\n")

        # Sort by position (top to bottom, left to right)
        sorted_results = sorted(
            results,
            key=lambda x: (
                -x["bounding_box"]["y"],  # Top to bottom (inverted Y)
                x["bounding_box"]["x"],  # Left to right
            ),
        )

        width, height = self.img.size

        for r in sorted_results:
            bb = r["bounding_box"]
            # Convert normalized coords to percentages
            x_pct = round(bb["x"] * 100, 1)
            y_pct = round((1 - bb["y"] - bb["height"]) * 100, 1)
            conf = round(r["confidence"] * 100, 1)

            print(f"  '{r['text']}' at ({x_pct}%, {y_pct}%) conf:{conf}%")

    def analyze_layout(self):
        """Analyze layout based on text positions"""
        results = self.recognize_text()

        if not results:
            return {}

        width, height = self.img.size

        # Categorize by Y position
        regions = {"header": [], "hero": [], "content": [], "footer": []}

        for r in results:
            bb = r["bounding_box"]
            y_center = 1 - bb["y"] - bb["height"] / 2  # Convert Vision Y (flipped)
            y_pct = y_center * 100

            if y_pct < 15:
                regions["header"].append(r["text"])
            elif y_pct < 45:
                regions["hero"].append(r["text"])
            elif y_pct < 80:
                regions["content"].append(r["text"])
            else:
                regions["footer"].append(r["text"])

        return regions


def main():
    parser = argparse.ArgumentParser(description="Vision OCR Tool")
    parser.add_argument("image_path", nargs="?", help="Path to image file")
    parser.add_argument(
        "--interactive", "-i", action="store_true", help="Interactive mode"
    )
    parser.add_argument(
        "--layout", "-l", action="store_true", help="Show layout analysis"
    )

    args = parser.parse_args()

    if args.interactive:
        desktop = os.path.expanduser("~/Desktop")
        files = [f for f in os.listdir(desktop) if f.startswith("Screenshot")]
        print("Available screenshots:")
        for i, f in enumerate(sorted(files), 1):
            print(f"  {i}. {f}")

        choice = input("\nSelect number: ").strip()
        if choice.isdigit():
            image_path = os.path.join(desktop, sorted(files)[int(choice) - 1])
        else:
            image_path = choice
    elif args.image_path:
        image_path = args.image_path
    else:
        desktop = os.path.expanduser("~/Desktop")
        files = [f for f in os.listdir(desktop) if f.startswith("Screenshot")]
        if files:
            files_sorted = sorted(
                files,
                key=lambda x: os.path.getmtime(os.path.join(desktop, x)),
                reverse=True,
            )
            image_path = os.path.join(desktop, files_sorted[0])
            print(f"Using: {files_sorted[0]}")
        else:
            print("No screenshot found")
            sys.exit(1)

    print(f"\n=== VISION OCR: {os.path.basename(image_path)} ===\n")

    ocr = VisionOCR(image_path)
    ocr.print_results()

    if args.layout:
        print("\n=== LAYOUT ANALYSIS ===")
        layout = ocr.analyze_layout()
        for region, texts in layout.items():
            if texts:
                print(f"\n[{region.upper()}]")
                for t in texts[:10]:
                    print(f"  {t}")


if __name__ == "__main__":
    main()
