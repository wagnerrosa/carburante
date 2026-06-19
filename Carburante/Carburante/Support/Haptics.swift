//
//  Haptics.swift
//  Carburante
//
//  Vocabulário tátil único (Fase 11). `.success` ao salvar, `.warning` ao
//  confirmar exclusão, `.selection` ao trocar moto/combustível e ao concluir
//  OCR. Centralizado para manter o feedback consistente em todo o app.
//

import UIKit

enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
