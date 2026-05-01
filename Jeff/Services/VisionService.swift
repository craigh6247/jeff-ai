import Foundation
import Vision
import CoreImage

/// Produces a short natural-language description of what's in a frame using
/// Apple's Vision framework. v1 uses a composition of classification +
/// saliency + text recognition rather than a full VLM; the resulting summary
/// is fed into the language model alongside the user's question.
public final class VisionService {
    public init() {}

    public struct SceneDescription: Sendable {
        public let summary: String
        public let labels: [String]
        public let recognizedText: [String]
    }

    public func describe(image: CGImage) async throws -> SceneDescription {
        async let labels = classify(image: image)
        async let text = recognizeText(image: image)
        let (l, t) = try await (labels, text)
        return SceneDescription(
            summary: Self.summarize(labels: l, text: t),
            labels: l,
            recognizedText: t
        )
    }

    private static func summarize(labels: [String], text: [String]) -> String {
        var parts: [String] = []
        if let primary = labels.first {
            parts.append("appears to show \(primary)")
        }
        if labels.count > 1 {
            let extras = labels.dropFirst().prefix(3).joined(separator: ", ")
            parts.append("with \(extras) also visible")
        }
        if !text.isEmpty {
            let snippet = text.prefix(3).joined(separator: " / ")
            parts.append("text reads: \(snippet)")
        }
        if parts.isEmpty {
            return "Camera frame is empty or could not be classified."
        }
        return "Scene " + parts.joined(separator: "; ") + "."
    }

    private func classify(image: CGImage) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNClassificationObservation]) ?? []
                let labels = observations
                    .filter { $0.confidence >= 0.4 }
                    .prefix(5)
                    .map { $0.identifier.replacingOccurrences(of: "_", with: " ") }
                continuation.resume(returning: Array(labels))
            }
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func recognizeText(image: CGImage) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let strings = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: strings)
            }
            request.recognitionLevel = .fast
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
