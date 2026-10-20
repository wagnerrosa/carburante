//
//  ChallengeImageStore.swift
//  Carburante
//
//  Imagens dos desafios vindas do Storage — capa (`challenge-covers`) e as
//  fotos da turma (hodômetro e foto do desafio, `fuel-log-photos`) — com cache
//  em memória e em disco (Caches/ChallengeImages — o sistema pode limpar, a
//  imagem só é baixada de novo). As policies dos buckets decidem quem vê; aqui
//  só baixa com a sessão.
//
//  A capa muda de nome a cada troca (`ChallengeCover.path`): o cache nunca fica
//  velho. A foto do abastecimento NÃO (o upload sobrescreve o mesmo caminho,
//  que a policy da turma exige): na 1ª vez que aparece em cada abertura do app,
//  confere a data do arquivo no bucket e baixa de novo se ele mudou depois da
//  cópia guardada (`isStale`). A foto que este iPhone tirou vem do próprio
//  disco (`PhotoStorage`), que é sempre a mais nova.
//

import ImageIO
import UIKit
import Supabase

@MainActor
@Observable
final class ChallengeImageStore {
    static let shared = ChallengeImageStore()

    /// Sobe quando uma imagem já mostrada é trocada (foto nova do desafio,
    /// arquivo que mudou no bucket): quem mostra lê o cache de novo.
    private(set) var replacements = 0

    @ObservationIgnored private let memory = NSCache<NSString, UIImage>()
    /// Mesma imagem pedida por duas telas ao mesmo tempo baixa uma vez só.
    @ObservationIgnored private var inFlight: [String: Task<Data?, Never>] = [:]
    /// Fotos do abastecimento já conferidas nesta abertura do app.
    @ObservationIgnored private var checked: Set<String> = []
    /// Versão de cada imagem na memória: trocar a imagem aposenta as cópias
    /// reduzidas da anterior (o NSCache não lista as chaves).
    @ObservationIgnored private var generations: [String: Int] = [:]

    private static let folderURL: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let url = caches.appendingPathComponent("ChallengeImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private init() {}

    /// Imagem já no aparelho (memória, disco ou foto do protótipo D0), sem
    /// rede. `maxPixel` = lado maior para exibir (miniatura, mural): decodifica
    /// reduzida — uma foto de 2048 px inteira ocupa ~12 MB de memória.
    func cachedImage(_ ref: String?, bucket: String = ChallengeCover.bucket, maxPixel: Int? = nil) -> UIImage? {
        guard let ref, !ref.isEmpty else { return nil }
        guard ChallengeCover.isRemote(ref) else { return ChallengeImageLoader.image(ref) }
        let key = Self.key(ref, bucket: bucket)
        let memoryKey = memoryKey(key, maxPixel: maxPixel)
        if let image = memory.object(forKey: memoryKey) { return image }
        guard let data = storedData(ref, key: key, bucket: bucket),
              let image = Self.decode(data, maxPixel: maxPixel) else { return nil }
        memory.setObject(image, forKey: memoryKey)
        return image
    }

    /// Do aparelho, senão baixa do bucket privado. nil = sem rede ou sem
    /// permissão (saiu do desafio, código trocado).
    func image(_ ref: String?, bucket: String = ChallengeCover.bucket, maxPixel: Int? = nil) async -> UIImage? {
        guard let ref, !ref.isEmpty else { return nil }
        let key = Self.key(ref, bucket: bucket)
        if let cached = cachedImage(ref, bucket: bucket, maxPixel: maxPixel) {
            await revalidate(ref, key: key, bucket: bucket)
            return cachedImage(ref, bucket: bucket, maxPixel: maxPixel) ?? cached
        }
        guard ChallengeCover.isRemote(ref), let data = await download(ref, key: key, bucket: bucket) else {
            return nil
        }
        checked.insert(key)
        return Self.decode(data, maxPixel: maxPixel).map { image in
            memory.setObject(image, forKey: memoryKey(key, maxPixel: maxPixel))
            return image
        }
    }

    /// Guarda os bytes que acabaram de sair deste iPhone (capa nova, foto do
    /// desafio trocada): aparecem na hora, sem baixar.
    func store(_ data: Data, for ref: String, bucket: String = ChallengeCover.bucket) {
        let key = Self.key(ref, bucket: bucket)
        write(data, key: key)
        checked.insert(key)
        retire(key)
    }

    /// Apaga o cache (conta apagada ou saída da conta).
    func removeAll() {
        memory.removeAllObjects()
        checked = []
        generations = [:]
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: Self.folderURL, includingPropertiesForKeys: nil)) ?? []
        for file in files { try? fm.removeItem(at: file) }
    }

    // MARK: Cópia guardada

    /// Bytes no aparelho: a foto que este iPhone tirou (`PhotoStorage`, sempre
    /// a mais nova) ou a cópia baixada.
    private func storedData(_ ref: String, key: String, bucket: String) -> Data? {
        if bucket == PhotoReference.bucket, let own = PhotoStorage.data(for: ref) {
            checked.insert(key)
            return own
        }
        return try? Data(contentsOf: Self.fileURL(key))
    }

    /// Foto do abastecimento: 1 vez por abertura do app, confere se o arquivo
    /// do bucket mudou depois da cópia guardada (o dono trocou a foto). Sem
    /// rede, fica a cópia até a próxima abertura.
    private func revalidate(_ ref: String, key: String, bucket: String) async {
        guard bucket == PhotoReference.bucket, ChallengeCover.isRemote(ref), !checked.contains(key) else { return }
        checked.insert(key)
        let savedAt = (try? Self.fileURL(key).resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate
        guard let info = try? await SyncService.shared.client.storage.from(bucket).info(path: ref) else { return }
        guard Self.isStale(savedAt: savedAt, remoteChangedAt: info.updatedAt ?? info.lastModified) else { return }
        if await download(ref, key: key, bucket: bucket) != nil {
            retire(key)
        }
    }

    /// A cópia guardada é mais velha que o arquivo do bucket. Sem data de um
    /// dos lados, fica a cópia (baixar de novo a cada abertura sairia caro).
    nonisolated static func isStale(savedAt: Date?, remoteChangedAt: Date?) -> Bool {
        guard let savedAt, let remoteChangedAt else { return false }
        return remoteChangedAt > savedAt
    }

    private func download(_ ref: String, key: String, bucket: String) async -> Data? {
        if let task = inFlight[key] { return await task.value }
        let task = Task { () -> Data? in
            guard let data = try? await SyncService.shared.client.storage.from(bucket).download(path: ref),
                  UIImage(data: data) != nil else {
                return nil
            }
            self.write(data, key: key)
            return data
        }
        inFlight[key] = task
        let data = await task.value
        inFlight[key] = nil
        return data
    }

    private func write(_ data: Data, key: String) {
        try? data.write(to: Self.fileURL(key), options: .atomic)
    }

    /// A imagem mudou: as cópias decodificadas da anterior saem de uso e quem
    /// mostra relê.
    private func retire(_ key: String) {
        generations[key, default: 0] += 1
        replacements += 1
    }

    private func memoryKey(_ key: String, maxPixel: Int?) -> NSString {
        "\(key)#\(generations[key, default: 0])@\(maxPixel ?? 0)" as NSString
    }

    /// Um arquivo por imagem: bucket + caminho, sem barras.
    private static func key(_ ref: String, bucket: String) -> String {
        "\(bucket)/\(ref)".replacingOccurrences(of: "/", with: "_")
    }

    private static func fileURL(_ key: String) -> URL {
        folderURL.appendingPathComponent(key)
    }

    /// Inteira, ou reduzida a `maxPixel` no lado maior (ImageIO decodifica já
    /// pequena, sem passar pela imagem cheia; aplica a orientação da câmera).
    nonisolated static func decode(_ data: Data, maxPixel: Int?) -> UIImage? {
        guard let maxPixel else { return UIImage(data: data) }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
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
