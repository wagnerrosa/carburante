//
//  ChallengeImageStore.swift
//  Carburante
//
//  Imagens dos desafios vindas do Storage (capa; fotos da turma na D6), com
//  cache em memória e em disco (Caches/ChallengeImages — o sistema pode
//  limpar, a imagem só é baixada de novo). Os nomes no bucket mudam a cada
//  troca (`ChallengeCover.path`), então o cache nunca fica velho.
//  As policies do bucket decidem quem vê; aqui só baixa com a sessão.
//

import UIKit
import Supabase

@MainActor
final class ChallengeImageStore {
    static let shared = ChallengeImageStore()

    private let memory = NSCache<NSString, UIImage>()
    /// Mesma imagem pedida por duas telas ao mesmo tempo baixa uma vez só.
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    private static let folderURL: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let url = caches.appendingPathComponent("ChallengeImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private init() {}

    /// Imagem já no aparelho (memória, disco ou foto do protótipo D0), sem rede.
    func cachedImage(_ ref: String?, bucket: String = ChallengeCover.bucket) -> UIImage? {
        guard let ref, !ref.isEmpty else { return nil }
        guard ChallengeCover.isRemote(ref) else { return ChallengeImageLoader.image(ref) }
        let key = Self.key(ref, bucket: bucket)
        if let image = memory.object(forKey: key as NSString) { return image }
        guard let image = UIImage(contentsOfFile: Self.fileURL(key).path(percentEncoded: false)) else { return nil }
        memory.setObject(image, forKey: key as NSString)
        return image
    }

    /// Do aparelho, senão baixa do bucket privado. nil = sem rede ou sem
    /// permissão (saiu do desafio, código trocado).
    func image(_ ref: String?, bucket: String = ChallengeCover.bucket) async -> UIImage? {
        if let cached = cachedImage(ref, bucket: bucket) { return cached }
        guard let ref, ChallengeCover.isRemote(ref) else { return nil }
        let key = Self.key(ref, bucket: bucket)
        if let task = inFlight[key] { return await task.value }
        let task = Task { () -> UIImage? in
            guard let data = try? await SyncService.shared.client.storage.from(bucket).download(path: ref) else {
                return nil
            }
            return self.save(data, key: key)
        }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        return image
    }

    /// Guarda os bytes que acabaram de subir: a capa nova aparece sem baixar.
    func store(_ data: Data, for ref: String, bucket: String = ChallengeCover.bucket) {
        save(data, key: Self.key(ref, bucket: bucket))
    }

    /// Apaga o cache (conta apagada ou saída da conta).
    func removeAll() {
        memory.removeAllObjects()
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: Self.folderURL, includingPropertiesForKeys: nil)) ?? []
        for file in files { try? fm.removeItem(at: file) }
    }

    @discardableResult
    private func save(_ data: Data, key: String) -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        try? data.write(to: Self.fileURL(key), options: .atomic)
        memory.setObject(image, forKey: key as NSString)
        return image
    }

    /// Um arquivo por imagem: bucket + caminho, sem barras.
    private static func key(_ ref: String, bucket: String) -> String {
        "\(bucket)/\(ref)".replacingOccurrences(of: "/", with: "_")
    }

    private static func fileURL(_ key: String) -> URL {
        folderURL.appendingPathComponent(key)
    }
}

nonisolated extension ChallengeCover {
    /// Foto escolhida → JPEG da capa: recorte 3:2 no centro, reduzido. O
    /// `draw` aplica a orientação da câmera (sai sempre em pé). Pesado para
    /// uma foto de 12 MP: chamar fora da main (`prepare`).
    static func jpeg(from image: UIImage) -> Data? {
        let crop = cropRect(for: image.size)
        guard crop.width > 0, crop.height > 0 else { return nil }
        let size = outputSize(for: crop.size)
        let scale = size.width / crop.width
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(x: -crop.minX * scale, y: -crop.minY * scale,
                                  width: image.size.width * scale, height: image.size.height * scale))
        }
        return rendered.jpegData(compressionQuality: jpegQuality)
    }

    /// Bytes da galeria → JPEG da capa, fora da main.
    static func prepare(_ data: Data) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            UIImage(data: data).flatMap(jpeg(from:))
        }.value
    }
}
