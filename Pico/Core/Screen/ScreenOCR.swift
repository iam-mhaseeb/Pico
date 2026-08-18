import CoreGraphics
import Foundation
import Vision

protocol ScreenOCRProviding {
    func lines(in image: CGImage, maxLines: Int) -> [OCRLine]
}

struct VisionScreenOCR: ScreenOCRProviding {
    func lines(in image: CGImage, maxLines: Int = 80) -> [OCRLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }

        let observations = (request.results ?? []).prefix(maxLines)
        return observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            // Vision boxes are bottom-left origin; convert to top-left for click_at.
            let box = observation.boundingBox
            return OCRLine(
                text: text,
                x: box.minX,
                y: 1 - box.maxY,
                width: box.width,
                height: box.height
            )
        }
    }
}
