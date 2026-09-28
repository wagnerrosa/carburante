//
//  PhotoViewerSheet.swift
//  Carburante
//
//  Foto do hodômetro guardada no registro: miniatura tocável
//  (`OdometerPhotoPreview`) + tela cheia com zoom (`PhotoViewerSheet`).
//  Mesma experiência no fluxo de abastecimento novo e na edição.
//

import SwiftUI

/// Miniatura da foto do hodômetro; tocar abre em tela cheia. Mostra a foto
/// recém-tirada (`pendingImage`, ainda não salva) ou a guardada (`reference`,
/// do disco ou baixada do Storage na hora do toque).
struct OdometerPhotoPreview: View {
    var pendingImage: UIImage?
    var reference: String?

    @State private var storedImage: UIImage?
    @State private var viewer: ViewerItem?
    @State private var isLoading = false
    @State private var failed = false

    private struct ViewerItem: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    private var thumbnail: UIImage? { pendingImage ?? storedImage }

    var body: some View {
        Button {
            Task { await open() }
        } label: {
            ZStack {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else if isLoading {
                    ProgressView()
                } else if failed {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                } else {
                    // Sem estilo: herda o `.tint` da moto (accentColor não segue).
                    Image(systemName: "photo")
                }
            }
            .frame(width: 32, height: 32)
            .background(Color(.tertiarySystemFill))
            .clipShape(.rect(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.borderless)
        .disabled(isLoading)
        .accessibilityLabel("Ver foto do hodômetro")
        // Só o disco aqui — baixar do Storage custa dados, fica para o toque.
        .task(id: reference) { storedImage = PhotoStorage.localImage(for: reference) }
        .sheet(item: $viewer) { PhotoViewerSheet(image: $0.image) }
    }

    private func open() async {
        if let thumbnail {
            viewer = ViewerItem(image: thumbnail)
            return
        }
        isLoading = true
        defer { isLoading = false }
        if let image = await SyncService.shared.odometerPhoto(for: reference) {
            failed = false
            storedImage = image
            viewer = ViewerItem(image: image)
        } else {
            failed = true
            Haptics.warning()
        }
    }
}

/// Tela cheia: pinça para zoom, arrasta quando ampliada, toque duplo volta.
struct PhotoViewerSheet: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(magnify.simultaneously(with: pan))
                    .onTapGesture(count: 2) {
                        withAnimation(.snappy) { reset() }
                    }
                    .accessibilityLabel("Foto do hodômetro")
            }
            .navigationTitle("Hodômetro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
        // Escopo local (não `preferredColorScheme`, que vaza para a tela de trás).
        .environment(\.colorScheme, .dark)
    }

    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { scale = min(max(baseScale * $0.magnification, 1), 5) }
            .onEnded { _ in
                baseScale = scale
                if scale == 1 { withAnimation(.snappy) { reset() } }
            }
    }

    private var pan: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(width: baseOffset.width + value.translation.width,
                                height: baseOffset.height + value.translation.height)
            }
            .onEnded { _ in baseOffset = offset }
    }

    private func reset() {
        scale = 1; baseScale = 1
        offset = .zero; baseOffset = .zero
    }
}
