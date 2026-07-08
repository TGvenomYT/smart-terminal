import Vision
import AppKit
import Foundation

guard CommandLine.arguments.count > 1 else {
    fputs("Usage: ocr-tool <image_path>\n", stderr)
    exit(1)
}

let imagePath = CommandLine.arguments[1]

guard FileManager.default.fileExists(atPath: imagePath) else {
    fputs("Error: file not found: \(imagePath)\n", stderr)
    exit(1)
}

guard let image = NSImage(contentsOfFile: imagePath),
      let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let cgImage = bitmap.cgImage else {
    fputs("Error: could not load image\n", stderr)
    exit(1)
}

let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.usesLanguageCorrection = true

do {
    try handler.perform([request])
} catch {
    fputs("Error: OCR failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}

guard let results = request.results, !results.isEmpty else {
    fputs("No text detected\n", stderr)
    exit(1)
}

for observation in results {
    if let candidate = observation.topCandidates(1).first {
        print(candidate.string)
    }
}
