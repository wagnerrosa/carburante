//
//  ActivityView.swift
//  Carburante
//
//  Folha de compartilhar nativa (UIActivityViewController) para arquivos —
//  Salvar em Arquivos, AirDrop, Mail. Usada pela exportação de dados.
//

import SwiftUI
import UIKit

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
