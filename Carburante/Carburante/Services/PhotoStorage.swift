//
//  PhotoStorage.swift
//  Carburante
//
//  Disco local das fotos do hodômetro (Documents/FuelPhotos/<fuel_log_id>.jpg).
//  Salva na hora (offline-first); o upload pro Supabase Storage é do
//  `SyncService`. Formato da referência guardada no FuelLog: `PhotoReference`.
//

import UIKit

enum PhotoStorage {
    /// Lado maior da foto guardada. 12 MP inteiros dão ~3 MB (o 1 GB grátis do
    /// Supabase lotaria em poucas centenas de fotos); 2048 px mantém os dígitos
    /// do hodômetro legíveis — inclusive para uma checagem por IA no futuro.
    static let maxDimension: CGFloat = 2048
    private static let jpegQuality: CGFloat = 0.7

    private static let folderURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent("FuelPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    /// Reduz e grava a foto como JPEG. Devolve a referência LOCAL (nome do
    /// arquivo) para `odometerPhotoURL`, ou nil se não conseguiu gravar.
    @discardableResult
    static func save(_ image: UIImage, for logID: UUID) -> String? {
        let fileName = PhotoReference.fileName(logID: logID)
        guard let data = downscaled(image).jpegData(compressionQuality: jpegQuality) else { return nil }
        do {
            try data.write(to: folderURL.appendingPathComponent(fileName), options: .atomic)
            return fileName
        } catch {
            return nil
        }
    }

    /// Bytes da foto no disco (para o upload). Aceita referência local ou
    /// remota — as duas terminam no mesmo nome de arquivo.
    static func data(for ref: String?) -> Data? {
        guard let url = fileURL(for: ref) else { return nil }
        return try? Data(contentsOf: url)
    }

    /// Foto no disco deste device, se houver (a remota é baixada pelo SyncService).
    static func localImage(for ref: String?) -> UIImage? {
        data(for: ref).flatMap(UIImage.init(data:))
    }

    /// Apaga todas as fotos locais (exclusão de conta).
    static func deleteAllLocal() {
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)) ?? []
        for file in files { try? fm.removeItem(at: file) }
    }

    private static func fileURL(for ref: String?) -> URL? {
        guard let ref, !ref.isEmpty else { return nil }
        return folderURL.appendingPathComponent((ref as NSString).lastPathComponent)
    }

    /// Redesenha no tamanho alvo. O `draw` aplica a orientação da câmera, então
    /// o JPEG sai sempre "em pé".
    private static func downscaled(_ image: UIImage) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image }
        let factor = maxDimension / longest
        let size = CGSize(width: (image.size.width * factor).rounded(),
                          height: (image.size.height * factor).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
