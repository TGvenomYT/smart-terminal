#!/usr/bin/env python3
"""
OCR using macOS Vision framework.
Extracts text from an image file using Apple's built-in OCR.
Works on macOS 12+ without any external dependencies.

Usage: python3 ocr.py <image_path>
"""

import sys
import os


def ocr_image(image_path):
    """Use macOS Vision framework via PyObjC or fallback to subprocess."""
    # Method 1: Try using the built-in macOS 'shortcuts' with a simple approach
    # Method 2: Use PyObjC Vision framework directly
    try:
        import Quartz
        import Vision
        from Foundation import NSURL

        # Load image
        image_url = NSURL.fileURLWithPath_(image_path)
        ci_image = Quartz.CIImage.imageWithContentsOfURL_(image_url)
        
        if ci_image is None:
            # Try loading as CGImage instead
            image_source = Quartz.CGImageSourceCreateWithURL(image_url, None)
            if image_source is None:
                return None
            cg_image = Quartz.CGImageSourceCreateImageAtIndex(image_source, 0, None)
            if cg_image is None:
                return None
        else:
            # Convert CIImage to CGImage
            context = Quartz.CIContext.context()
            extent = ci_image.extent()
            cg_image = context.createCGImage_fromRect_(ci_image, extent)

        # Create VNImageRequestHandler
        handler = Vision.VNImageRequestHandler.alloc().initWithCGImage_options_(cg_image, None)
        
        # Create text recognition request
        request = Vision.VNRecognizeTextRequest.alloc().init()
        request.setRecognitionLevel_(Vision.VNRequestTextRecognitionLevelAccurate)
        
        # Perform request
        success = handler.performRequests_error_([request], None)
        
        if not success[0]:
            return None
        
        # Extract text from results
        results = request.results()
        if not results:
            return None
        
        texts = []
        for observation in results:
            candidates = observation.topCandidates_(1)
            if candidates:
                texts.append(candidates[0].string())
        
        return "\n".join(texts) if texts else None

    except ImportError:
        # PyObjC not available, fall back to osascript approach
        pass

    # Method 3: Fallback using a temporary shortcut-like approach with screencapture metadata
    # Use the `swift` command to call Vision framework
    import subprocess
    import tempfile
    
    swift_code = f'''
import Vision
import AppKit

let imagePath = "{image_path}"
guard let image = NSImage(contentsOfFile: imagePath),
      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {{
    exit(1)
}}

let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate

try? handler.perform([request])

guard let results = request.results else {{ exit(1) }}

for observation in results {{
    if let candidate = observation.topCandidates(1).first {{
        print(candidate.string)
    }}
}}
'''
    
    with tempfile.NamedTemporaryFile(mode='w', suffix='.swift', delete=False) as f:
        f.write(swift_code)
        swift_file = f.name
    
    try:
        result = subprocess.run(
            ['swift', swift_file],
            capture_output=True, text=True, timeout=15
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass
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
        sys.exit(1)


if __name__ == "__main__":
    main()
