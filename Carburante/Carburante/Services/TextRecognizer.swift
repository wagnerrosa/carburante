//
//  TextRecognizer.swift
//  Carburante
//
//  Wrapper do Vision: imagem → linhas de texto reconhecidas + confiança média.
//  Processamento on-device (sem rede). Isola o framework do resto do app.
//
//  Duas correções do PLAN/ocr-hodometro.md §6 (Fase 1):
//  - orientação: o `cgImage` de um `UIImage` vem com os pixels do sensor, sem
//    a rotação do EXIF. Foto em retrato chegava deitada ao Vision — agora a
//    orientação do `UIImage` vai junto no handler;
//  - thread: `perform` é síncrono e pesado (foto de 12 MP) — roda fora da main
//    (o target tem MainActor como isolamento padrão), a UI não trava mais.
//

import Foundation
import Vision
import UIKit

nonisolated struct RecognizedText: Sendable {
    let lines: [String]
    /// Confiança média das observações (0...1). nil se nada reconhecido.
    let confidence: Double?
}

nonisolated enum TextRecognizerError: Error {
    case noImage
    case requestFailed(Error)
}

enum TextRecognizer {

    /// Reconhece texto numa foto respeitando a orientação dela.
    static func recognize(in image: UIImage) async throws -> RecognizedText {
        guard let cgImage = image.cgImage else { throw TextRecognizerError.noImage }
        return try await recognize(in: cgImage,
                                   orientation: CGImagePropertyOrientation(image.imageOrientation))
    }

    /// Reconhece texto em pixels crus (on-device, precisão alta, idioma pt-BR),
    /// fora da main thread. `orientation` diz como girar os pixels para ficar
    /// em pé; `.up` = sem rotação (comportamento antigo, baseline do benchmark).
    static func recognize(in cgImage: CGImage,
                          orientation: CGImagePropertyOrientation = .up) async throws -> RecognizedText {
        try await Task.detached(priority: .userInitiated) {
            try perform(cgImage, orientation: orientation)
        }.value
    }

    private nonisolated static func perform(_ cgImage: CGImage,
                                            orientation: CGImagePropertyOrientation) throws -> RecognizedText {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false   // números/displays: correção atrapalha
        request.recognitionLanguages = ["pt-BR"]

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw TextRecognizerError.requestFailed(error)
        }

        var lines: [String] = []
        var confidences: [Float] = []
        for obs in request.results ?? [] {
            guard let top = obs.topCandidates(1).first else { continue }
            lines.append(top.string)
            confidences.append(top.confidence)
        }
        let avg = confidences.isEmpty ? nil : Double(confidences.reduce(0, +) / Float(confidences.count))
        return RecognizedText(lines: lines, confidence: avg)
    }
}

extension CGImagePropertyOrientation {
    /// `UIImage.Orientation` e `CGImagePropertyOrientation` têm os mesmos casos
    /// com valores brutos diferentes — mapeamento explícito.
    nonisolated init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
