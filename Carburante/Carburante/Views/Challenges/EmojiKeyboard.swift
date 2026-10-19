//
//  EmojiKeyboard.swift
//  Carburante
//
//  "Outro emoji" das reações: abre o teclado de emoji do iPhone (como o "+"
//  do Tapback no iOS 18) e devolve o primeiro emoji tocado. Campo invisível —
//  o SwiftUI não tem teclado de emoji, então o pedido vai pelo UIKit.
//

import SwiftUI
import UIKit

struct EmojiKeyboard: UIViewRepresentable {
    @Binding var isPresented: Bool
    var onPick: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> EmojiTextField {
        let field = EmojiTextField()
        field.delegate = context.coordinator
        field.tintColor = .clear
        field.accessibilityElementsHidden = true
        field.inputAccessoryView = context.coordinator.makeAccessory()
        return field
    }

    func updateUIView(_ field: EmojiTextField, context: Context) {
        context.coordinator.parent = self
        if isPresented, !field.isFirstResponder {
            // Espera o campo entrar na janela.
            DispatchQueue.main.async { field.becomeFirstResponder() }
        } else if !isPresented, field.isFirstResponder {
            field.resignFirstResponder()
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: EmojiKeyboard

        init(_ parent: EmojiKeyboard) { self.parent = parent }

        /// Barra acima do teclado: diz o que fazer e deixa desistir.
        func makeAccessory() -> UIToolbar {
            let bar = UIToolbar()
            let title = UILabel()
            title.text = "Reagir com um emoji"
            title.font = .preferredFont(forTextStyle: .subheadline)
            title.textColor = .secondaryLabel
            bar.items = [
                UIBarButtonItem(customView: title),
                .flexibleSpace(),
                UIBarButtonItem(title: "Cancelar", primaryAction: UIAction { [weak self] _ in
                    self?.parent.isPresented = false
                }),
            ]
            bar.sizeToFit()
            return bar
        }

        /// O campo nunca guarda texto: o primeiro emoji válido vira reação e
        /// fecha o teclado. Letra ou número (outro teclado) é ignorado.
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool {
            if ChallengeReaction.isSingleEmoji(string) {
                parent.onPick(string)
                parent.isPresented = false
            }
            return false
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if parent.isPresented { parent.isPresented = false }
        }
    }
}

/// Campo que pede o teclado de emoji ao abrir (se a pessoa tiver o teclado
/// de emoji ativo, que é o padrão do iPhone; senão abre o teclado normal e
/// ela troca no globo).
final class EmojiTextField: UITextField {
    override var textInputContextIdentifier: String? { "" }

    override var textInputMode: UITextInputMode? {
        UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" } ?? super.textInputMode
    }
}
