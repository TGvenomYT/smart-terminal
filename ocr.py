#!/usr/bin/env python3
"""
OCR using macOS Vision framework via precompiled Swift tool.
Falls back to on-the-fly Swift compilation if binary not found.

Usage: python3 ocr.py <image_path>
"""

import sys
import os
import subprocess


def ocr_image(image_path):
    """Run OCR on an image file. Returns extracted text or None."""
    
    # Resolve absolute path
    image_path = os.path.abspath(image_path)
    
    # Method 1: Use precompiled ocr-tool binary (fast, reliable)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    ocr_tool = os.path.join(script_dir, "bin", "ocr-tool")
    
    # Also check installed location
    if not os.path.isfile(ocr_tool):
        ocr_tool = os.path.expanduser("~/.smart-terminal/bin/ocr-tool")
    
    if os.path.isfile(ocr_tool):
        try:
            result = subprocess.run(
                [ocr_tool, image_path],
                capture_output=True, text=True, timeout=30
            )
            if result.returncode == 0 and result.stdout.strip():
                return result.stdout.strip()
            # Print stderr for debugging
            if result.stderr.strip():
                print(f"ocr-tool: {result.stderr.strip()}", file=sys.stderr)
        except subprocess.TimeoutExpired:
            print("ocr-tool: timed out", file=sys.stderr)
        except Exception as e:
            print(f"ocr-tool: {e}", file=sys.stderr)

    # Method 2: Compile and run Swift inline (slower, but works without precompiled binary)
    swift_code = f'''
import Vision
import AppKit
import Foundation

let imagePath = "{image_path}"
guard let image = NSImage(contentsOfFile: imagePath),
      let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let cgImage = bitmap.cgImage else {{
    fputs("Error: could not load image\\n", stderr)
    exit(1)
}}

let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.usesLanguageCorrection = true

do {{
    try handler.perform([request])
}} catch {{
    fputs("Error: \\(error.localizedDescription)\\n", stderr)
    exit(1)
}}

guard let results = request.results, !results.isEmpty else {{
    exit(1)
}}

for observation in results {{
    if let candidate = observation.topCandidates(1).first {{
        print(candidate.string)
    }}
}}
'''
    import tempfile
    with tempfile.NamedTemporaryFile(mode='w', suffix='.swift', delete=False) as f:
        f.write(swift_code)
        swift_file = f.name

    try:
        result = subprocess.run(
            ['swift', swift_file],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
        if result.stderr.strip():
            print(f"swift: {result.stderr.strip()}", file=sys.stderr)
    except subprocess.TimeoutExpired:
        print("swift: timed out (try running install.sh to compile ocr-tool)", file=sys.stderr)
    except FileNotFoundError:
        print("swift: not found", file=sys.stderr)
    finally:
        os.unlink(swift_file)

    return None


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 ocr.py <image_path>", file=sys.stderr)
        sys.exit(1)

    image_path = sys.argv[1]
    if not os.path.exists(image_path):
        print(f"Error: File not found: {image_path}", file=sys.stderr)
        sys.exit(1)

    text = ocr_image(image_path)
    if text:
        print(text)
    else:
        print("No text could be extracted from the image.", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
