# Image Analysis Skill

Analyze screenshots and images using OCR to understand visual issues, validate UI implementations, and extract text content.

## Quick Start

```bash
# Run enhanced analysis with Tesseract (recommended)
python3 ~/.claude/skills/image-analysis/image_analyzer.py /path/to/screenshot.png

# Interactive mode (auto-finds screenshots on Desktop)
python3 ~/.claude/skills/image-analysis/image_analyzer.py --interactive

# Analyze and save report
python3 ~/.claude/skills/image-analysis/image_analyzer.py /path/to/screenshot.png -s -v
```

## Setup

```bash
# Install dependencies (macOS)
brew install tesseract tesseract-lang
pip3 install --break-system-packages Pillow pytesseract numpy

# Verify
tesseract --version
python3 -c "from PIL import Image; import pytesseract; print('OK')"
```

## Enhanced Image Analyzer

The recommended tool for analyzing screenshots:

```python
from image_analyzer import EnhancedImageAnalyzer

analyzer = EnhancedImageAnalyzer('/path/to/screenshot.png')
analyzer.run_full_analysis()
analyzer.print_report()
```

### Features

1. **Multiple OCR Methods** - Tries basic, aggressive, and upscaled preprocessing
2. **Confidence Scoring** - Reports OCR confidence percentage (81%+ typical)
3. **Layout Analysis** - Breaks down content by page region
4. **Word Positions** - Shows exact position of each word
5. **Color Analysis** - Detects brand colors and their percentages

### Example Output

```
============================================================
ENHANCED IMAGE ANALYSIS REPORT
============================================================

📷 IMAGE INFO
   Path: /path/to/screenshot.png
   Size: 1146x821

🎨 COLOR ANALYSIS
   navy (#0B2D4E): 15.5%
   teal (#199B93): 3.2%
   white (#FFFFFF): 45.0%
   gray-100 (#F3F4F6): 12.9%

📝 TEXT EXTRACTION (Best Method)
   Confidence: 81.0%
   
   Text Content:
      THINK FUNDING Home About Funding Solutions Industries Resources
      Smarter Business Funding for Growing Companies
      Fast, flexible, and structured funding...
      ...

📐 LAYOUT ANALYSIS
   [HEADER] (1146x98)
      Navigation and logo
   
   [HERO] (1146x230)
      Main headline and CTAs
   
   [CONTENT] (1146x246)
      Value propositions
   
   [CTA] (1146x123)
      Call to action
   
   [FOOTER] (1146x124)
      Footer content

📍 KEY WORD POSITIONS
   'THINK' at (12.8%, 2.3%)
   'FUNDING' at (20.8%, 2.3%)
   'Home' at (43.4%, 3.4%)
   ...
```

## Analysis Workflow

### 1. Find Screenshots

```python
import os
desktop = os.path.expanduser("~/Desktop")
files = [f for f in os.listdir(desktop) if f.startswith('Screenshot')]
# Get most recent
files_sorted = sorted(files, key=lambda x: os.path.getmtime(os.path.join(desktop, x)), reverse=True)
print(files_sorted[0])
```

### 2. Run Full Analysis

```python
analyzer = EnhancedImageAnalyzer('/path/to/screenshot.png')
results = analyzer.run_full_analysis()

# Access results
print(results['text']['best']['text'])  # OCR text
print(results['colors'])  # Color analysis
print(results['words'])  # Word positions
```

### 3. Interpret Results

| Metric | What It Means |
|--------|---------------|
| Confidence > 80% | Good OCR accuracy |
| Confidence 60-80% | Some garbled text likely |
| Confidence < 60% | Significant OCR errors |

### 4. Color Analysis

```python
navy_pct = results['colors']['navy (#0B2D4E)']['percentage']
teal_pct = results['colors']['teal (#199B93)']['percentage']
print(f"Navy: {navy_pct}%, Teal: {teal_pct}%")
```

## Layout Regions

The analyzer divides the image into these regions:

| Region | Y Position | Typical Content |
|--------|------------|-----------------|
| header | 0-12% | Navigation, logo |
| hero | 12-40% | Main headline, CTAs |
| content | 40-70% | Value props, features |
| cta | 70-85% | Call to action |
| footer | 85-100% | Footer links, legal |

## Tips for Better OCR

1. **Use high-resolution screenshots** (retina displays best)
2. **Good contrast** between text and background
3. **Minimal compression** - PNG over JPEG
4. **Check confidence scores** - below 70% may indicate issues
5. **Isolate text regions** when possible

## Common OCR Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "Wey" vs "Way" | Font similarity | Use aggressive preprocessing |
| Garbled text | Low resolution | Upscale 2x preprocessing |
| Missing words | Threshold too high | Reduce contrast |
| Icon误读 | Layout noise | Filter by confidence score |

## Interactive Mode

```bash
python3 ~/.claude/skills/image-analysis/image_analyzer.py --interactive
```

This will:
1. List all screenshots on Desktop
2. Let you select which to analyze
3. Run full analysis
4. Offer to save report

## Save Reports

```bash
python3 ~/.claude/skills/image-analysis/image_analyzer.py /path/to/screenshot.png -s
```

Creates `screenshot.png_analysis.txt` with full report.

## Skill Files

- `image_analyzer.py` - Enhanced analyzer with Tesseract
- `SKILL.md` - This documentation

## Usage in OpenCode

When asked to analyze a screenshot:

1. **Use the enhanced analyzer** (always):
   ```python
   from image_analyzer import EnhancedImageAnalyzer
   analyzer = EnhancedImageAnalyzer('/path/to/screenshot.png')
   analyzer.run_full_analysis()
   analyzer.print_report()
   ```

2. **Check confidence** - if below 70%, note that OCR may have errors

3. **Use word positions** to understand layout without visual

4. **Compare against code** to identify discrepancies

5. **Report findings** clearly:
   - What text was extracted
   - What layout regions exist
   - What colors are present
   - Any OCR confidence concerns
```
