//
//  BrandTheme.swift
//  Carburante
//
//  Tema dinâmico: a cor de destaque (accent/tint) do app reflete a MARCA da
//  moto. Não reproduz o branding da fabricante — só dá uma identidade visual
//  pessoal a cada moto. Estrutura, tipografia, espaçamento e layout NÃO mudam;
//  só a accent color (CTA, controles, links, gráficos, indicadores).
//
//  Fonte única de verdade da cor → todas as telas derivam de `Motorcycle.themeColor`,
//  que delega a este mapa. Marca fora do catálogo (ou "Outra…") cai no
//  `.default` (laranja do sistema — accent padrão do app).
//
//  Preparado para tema por-MODELO no futuro: a derivação está centralizada em
//  `BrandTheme.color(make:model:)`; basta adicionar regras por modelo lá sem
//  tocar nas views.
//

import SwiftUI

enum BrandTheme {
    /// Accent padrão do app quando a marca não tem cor mapeada.
    static let `default`: Color = .orange  // iOS systemOrange

    /// Cor de destaque por marca. Tons sólidos derivados das marcas, mas
    /// adaptados ao visual nativo (sem saturação excessiva — legibilidade).
    /// Chave normalizada (minúscula, sem acento/variação) para casar com
    /// `Motorcycle.make` mesmo se a grafia divergir um pouco.
    private static let byMake: [String: Color] = [
        "honda":           Color(hex: 0xE40521),  // Vermelho Honda
        "yamaha":          Color(hex: 0x0033A0),  // Azul Yamaha
        "bmw":             Color(hex: 0x0066B1),  // Azul BMW
        "suzuki":          Color(hex: 0x005BAC),  // Azul Suzuki
        "harley-davidson": Color(hex: 0xFF6600),  // Laranja Harley-Davidson
        "royal enfield":   Color(hex: 0x7A2E1F),  // Marrom/Bordô Royal Enfield
        "ducati":          Color(hex: 0xCC0000),  // Vermelho Ducati
        "kawasaki":        Color(hex: 0x6DB33F),  // Verde Kawasaki
        "triumph":         Color(hex: 0x111111),  // Preto Triumph
        "ktm":             Color(hex: 0xFF6600),  // Laranja KTM
    ]

    /// Cor de destaque para uma moto. `model` aceito desde já para suportar
    /// override por modelo no futuro (hoje ignorado — decide só pela marca).
    static func color(make: String, model: String? = nil) -> Color {
        let key = make
            .folding(options: .diacriticInsensitive, locale: nil)
            .lowercased()
            .trimmingCharacters(in: .whitespaces)
        return byMake[key] ?? Self.default
    }
}

extension Color {
    /// Cor de marca a partir de um literal 0xRRGGBB, **adaptada ao esquema**.
    ///
    /// Marcas como Triumph (#111111) e Royal Enfield (#7A2E1F) somem como
    /// glifo/texto sobre o fundo escuro do Dark Mode; cores muito claras somem
    /// no Light Mode. Para manter a identidade (matiz) sem sacrificar
    /// legibilidade (HIG/acessibilidade), clareamos accents escuros demais no
    /// Dark Mode e escurecemos accents claros demais no Light Mode — só nos
    /// extremos; cores de luminância média passam intactas.
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self = Color(UIColor { traits in
            let dark = traits.userInterfaceStyle == .dark
            // Luminância perceptual aproximada (Rec. 709).
            let lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
            // Pisos/tetos para o accent ser visível como glifo no fundo do sistema.
            let floorDark = 0.42   // no escuro, não deixe escurecer demais
            let ceilLight = 0.62   // no claro, não deixe clarear demais
            func mix(_ c: Double, toward target: Double, by t: Double) -> Double {
                c + (target - c) * t
            }
            var (rr, gg, bb) = (r, g, b)
            if dark, lum < floorDark {
                // clareia em direção ao branco proporcional ao quão escuro está
                let t = (floorDark - lum) / floorDark
                rr = mix(r, toward: 1, by: t); gg = mix(g, toward: 1, by: t); bb = mix(b, toward: 1, by: t)
            } else if !dark, lum > ceilLight {
                // escurece em direção ao preto proporcional ao quão claro está
                let t = (lum - ceilLight) / (1 - ceilLight)
                rr = mix(r, toward: 0, by: t); gg = mix(g, toward: 0, by: t); bb = mix(b, toward: 0, by: t)
            }
            return UIColor(red: rr, green: gg, blue: bb, alpha: 1)
        })
    }
}

extension Motorcycle {
    /// Cor de destaque desta moto — fonte única que as telas consomem.
    var themeColor: Color {
        BrandTheme.color(make: make, model: model)
    }
}
