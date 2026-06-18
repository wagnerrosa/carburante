//
//  TextRecognizer.swift
//  Carburante
//
//  Wrapper do Vision: imagem → linhas de texto reconhecidas + confiança média.
//  Processamento on-device (sem rede). Isola o framework do resto do app.
//

import Foundation
import Vision
import CoreGraphics

struct RecognizedText {
    let lines: [String]
    /// Confiança média das observações (0...1). nil se nada reconhecido.
    let confidence: Double?
}

enum TextRecognizerError: Error {
    case noImage
    case requestFailed(Error)
}

enum TextRecognizer {

    /// Reconhece texto numa imagem (on-device, precisão alta, idioma pt-BR).
    static func recognize(in cgImage: CGImage) async throws -> RecognizedText {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: TextRecognizerError.requestFailed(error))
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                var lines: [String] = []
                var confidences: [Float] = []
                for obs in observations {
                    guard let top = obs.topCandidates(1).first else { continue }
                    lines.append(top.string)
                    confidences.append(top.confidence)
                }
                let avg = confidences.isEmpty ? nil : Double(confidences.reduce(0, +) / Float(confidences.count))
                continuation.resume(returning: RecognizedText(lines: lines, confidence: avg))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false   // números/displays: correção atrapalha
            request.recognitionLanguages = ["pt-BR"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: TextRecognizerError.requestFailed(error))
            }
        }
    }
}
