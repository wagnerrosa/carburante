//
//  FuelLocationMap.swift
//  Carburante
//
//  Mini-mapa estático do local do abastecimento (Fase 2 — insights,
//  antecipado). GPS já é capturado em FuelLog (lat/long). Padrão Wallet/Fotos:
//  card não-interativo com um marcador, tap abre o app Mapas nativo.
//  Reusado depois no mapa de todos os abastecimentos.
//

import SwiftUI
import MapKit

/// Mini-mapa estático centrado em uma coordenada, com marcador.
/// Não-interativo; tap abre o local no app Mapas.
struct FuelLocationMap: View {
    let latitude: Double
    let longitude: Double
    /// Rótulo do marcador / título no Mapas (ex.: cidade ou "Abastecimento").
    var label: String = "Abastecimento"
    var height: CGFloat = 150

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
        )
    }

    var body: some View {
        Map(initialPosition: .region(region), interactionModes: []) {
            Marker(label, coordinate: coordinate)
                .tint(.red)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .allowsHitTesting(true)
        .onTapGesture { openInMaps() }
        .accessibilityLabel("Local do abastecimento. Toque para abrir no Mapas.")
    }

    private func openInMaps() {
        let placemark = MKPlacemark(coordinate: coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = label
        item.openInMaps()
    }
}
