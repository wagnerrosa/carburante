//
//  FuelLogFormView.swift
//  Carburante
//
//  Novo abastecimento — entrada manual + OCR (Fase 6). O OCR pré-preenche
//  os campos; a revisão antes de salvar é obrigatória (OCR é auxílio).
//

import SwiftUI
import SwiftData
import PhotosUI

struct FuelLogFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let motorcycle: Motorcycle
    /// Nil = novo abastecimento. Não-nil = edição.
    var fuelLog: FuelLog?

    @State private var date: Date = Date()
    @State private var odometer: Double?
    @State private var liters: Double?
    @State private var totalCost: Double?
    @State private var fuelType: FuelType = .gasolinaComum
    @State private var isFullTank: Bool = true
    @State private var validationMessage: String?
    @FocusState private var fieldFocused: Bool

    // Localização (capturada em background ao abrir um novo registro)
    @State private var locationService = LocationService()
    @State private var location: LocationSnapshot?

    // OCR
    @State private var ocrProcessed = false
    @State private var ocrConfidence: Double?
    @State private var ocrStatus: String?
    @State private var isRecognizing = false
    @State private var showCameraFor: PhotoTarget?
    @State private var galleryItem: PhotosPickerItem?
    @State private var galleryTarget: PhotoTarget = .receipt

    /// Qual campo a foto alimenta.
    private enum PhotoTarget: Identifiable {
        case odometer   // foto do painel
        case receipt    // foto da bomba/comprovante
        var id: Int { self == .odometer ? 0 : 1 }
    }

    private var isEditing: Bool { fuelLog != nil }

    /// É o primeiro abastecimento da moto (ignorando o próprio log em edição)?
    private var isFirstFuelUp: Bool {
        motorcycle.fuelLogs.allSatisfy { $0.persistentModelID == fuelLog?.persistentModelID }
    }

    /// Maior hodômetro registrado p/ a moto, ignorando o próprio log em edição.
    private var lastOdometer: Double {
        let logsMax = motorcycle.fuelLogs
            .filter { $0.persistentModelID != fuelLog?.persistentModelID }
            .map(\.odometer).max() ?? 0
        return max(logsMax, motorcycle.currentOdometer)
    }

    /// Piso de validação ("não pode ser menor que o último"). Vale só para
    /// registro NOVO — ao editar um log histórico, a regra monotônica trancaria
    /// a edição (não dá pra baixar o valor), então é relaxada.
    private var odometerFloor: Double? {
        guard fuelLog == nil, lastOdometer > 0 else { return nil }
        return lastOdometer
    }

    private var pricePerLiter: Double? {
        guard let l = liters, l > 0, let c = totalCost else { return nil }
        return c / l
    }

    /// Aviso de hodômetro retrógrado, ao vivo (não só ao salvar).
    private var odometerWarning: String? {
        guard let odo = odometer, odo > 0, let floor = odometerFloor, odo < floor else { return nil }
        return "Hodômetro menor que o último (\(AppFormat.km(floor)))."
    }

    /// Consumo estimado deste tanque: km desde o último registro ÷ litros.
    /// Só faz sentido em tanque cheio (modelo full-to-full).
    private var liveKmPerLiter: Double? {
        guard isFullTank, let odo = odometer, let l = liters, l > 0,
              lastOdometer > 0, odo > lastOdometer else { return nil }
        return (odo - lastOdometer) / l
    }

    /// Mesma regra do validador — habilita "Salvar" só com dados válidos.
    private var canSave: Bool {
        FuelLogValidator.validate(
            odometer: odometer ?? 0,
            liters: liters ?? 0,
            totalCost: totalCost ?? 0,
            lastOdometer: odometerFloor
        ).isEmpty
    }

    /// Placeholder do hodômetro: último valor conhecido, deixa claro que é leitura total.
    private var odometerPrompt: String {
        lastOdometer > 0 ? "Último: \(AppFormat.odometer(lastOdometer)) km" : "Hodômetro atual"
    }

    var body: some View {
        NavigationStack {
            Form {
                // Identidade da moto — abrindo do Resumo (com seletor) não fica
                // claro pra qual moto é o registro; esta linha confirma.
                Section {
                    HStack(spacing: 12) {
                        IconTile(systemName: "motorcycle", tint: .blue, size: 34)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(motorcycle.displayName)
                                .font(.headline)
                            Text(isEditing ? "Editando abastecimento" : "Novo abastecimento")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                ocrSection
                Section {
                    DatePicker("Data", selection: $date, displayedComponents: [.date, .hourAndMinute])

                    HStack {
                        TextField("Hodômetro atual", value: $odometer, format: .number, prompt: Text(odometerPrompt))
                            .keyboardType(.decimalPad)
                            .focused($fieldFocused)
                        Text("km").foregroundStyle(.secondary)
                    }
                    HStack {
                        TextField("Litros", value: $liters, format: .number, prompt: Text("Litros"))
                            .keyboardType(.decimalPad)
                            .focused($fieldFocused)
                        Text("L").foregroundStyle(.secondary)
                    }
                    HStack {
                        TextField("Valor total", value: $totalCost, format: .number, prompt: Text("Valor total"))
                            .keyboardType(.decimalPad)
                            .focused($fieldFocused)
                        Text("R$").foregroundStyle(.secondary)
                    }
                    Picker("Combustível", selection: $fuelType) {
                        ForEach(FuelType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    Toggle("Tanque cheio", isOn: $isFullTank)
                } header: {
                    Text("Abastecimento")
                } footer: {
                    if isFirstFuelUp {
                        Text("Encha o tanque neste primeiro registro para começar a medir o consumo.")
                    } else {
                        Text("Desligue se você não encheu o tanque. Abastecimentos parciais são somados e o consumo é fechado no próximo tanque cheio.")
                    }
                }

                if pricePerLiter != nil || liveKmPerLiter != nil {
                    Section {
                        if let ppl = pricePerLiter {
                            LabeledContent("Preço por litro") {
                                Text(AppFormat.currencyPrecise(ppl)).monospacedDigit()
                            }
                        }
                        if let est = liveKmPerLiter {
                            LabeledContent("Consumo estimado") {
                                Text(AppFormat.kmPerLiter(est)).monospacedDigit()
                            }
                        }
                    } footer: {
                        if liveKmPerLiter != nil {
                            Text("Estimativa deste tanque pelo hodômetro anterior — o consumo oficial é fechado no próximo tanque cheio.")
                        }
                    }
                }

                if let warning = odometerWarning {
                    Section {
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }

                if let msg = validationMessage {
                    Section {
                        Label(msg, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "Editar" : "Abastecimento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { save() }
                        .disabled(!canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Concluir") { fieldFocused = false }
                }
            }
            .onAppear(perform: loadIfEditing)
            .task {
                // Captura localização só em registro novo; best-effort, não bloqueia.
                guard fuelLog == nil else { return }
                location = await locationService.currentSnapshot()
            }
            .fullScreenCover(item: $showCameraFor) { target in
                CameraPicker { image in
                    Task { await process(image, for: target) }
                }
                .ignoresSafeArea()
            }
            .onChange(of: galleryItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await process(image, for: galleryTarget)
                    }
                    galleryItem = nil
                }
            }
        }
    }

    // MARK: - OCR

    @ViewBuilder
    private var ocrSection: some View {
        Section {
            photoControls(target: .odometer, label: "Foto do hodômetro", icon: "gauge")
            photoControls(target: .receipt, label: "Foto da bomba/comprovante", icon: "doc.text.viewfinder")
        } header: {
            Text("Foto (OCR)")
        } footer: {
            if isRecognizing {
                Label("Lendo imagem…", systemImage: "hourglass")
            } else if let status = ocrStatus {
                Text(status)
            } else {
                Text("Fotografe e revise — o OCR é um auxílio, os valores podem precisar de correção.")
            }
        }
    }

    @ViewBuilder
    private func photoControls(target: PhotoTarget, label: String, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    showCameraFor = target
                } label: {
                    Image(systemName: "camera")
                }
                .buttonStyle(.borderless)
            }
            PhotosPicker(selection: $galleryItem, matching: .images) {
                Image(systemName: "photo")
            }
            .buttonStyle(.borderless)
            .simultaneousGesture(TapGesture().onEnded { galleryTarget = target })
        }
        .disabled(isRecognizing)
    }

    private func process(_ image: UIImage, for target: PhotoTarget) async {
        guard let cgImage = image.cgImage else { return }
        isRecognizing = true
        ocrStatus = nil
        defer { isRecognizing = false }

        do {
            let recognized = try await TextRecognizer.recognize(in: cgImage)
            switch target {
            case .odometer:
                if let odo = OCRParser.parseOdometer(recognized.lines) {
                    odometer = odo
                    ocrStatus = "Hodômetro lido: \(AppFormat.km(odo)). Confira."
                } else {
                    ocrStatus = "Não consegui ler o hodômetro. Digite manualmente."
                }
            case .receipt:
                let result = OCRParser.parseFuelReceipt(recognized.lines)
                if let l = result.liters { liters = l }
                if let c = result.totalCost { totalCost = c }
                if let f = result.fuelType { fuelType = f }
                let got = [result.liters != nil ? "litros" : nil,
                           result.totalCost != nil ? "valor" : nil,
                           result.fuelType != nil ? "combustível" : nil].compactMap { $0 }
                ocrStatus = got.isEmpty
                    ? "Não consegui ler o comprovante. Preencha manualmente."
                    : "Lido: \(got.joined(separator: ", ")). Confira os valores."
            }
            ocrProcessed = true
            ocrConfidence = recognized.confidence
            Haptics.selection()
        } catch {
            ocrStatus = "Falha ao processar a imagem."
        }
    }

    private func loadIfEditing() {
        if let log = fuelLog {
            date = log.date
            odometer = log.odometer
            liters = log.liters
            totalCost = log.totalCost
            fuelType = log.fuelType
            isFullTank = log.isFullTank
        } else if let last = motorcycle.latestFuelLog {
            // Novo registro: pré-seleciona o último combustível usado.
            fuelType = last.fuelType
        }
    }

    private func save() {
        // Campo vazio (nil) → 0, reprovado pela validação (positivos obrigatórios).
        let odo = odometer ?? 0
        let lit = liters ?? 0
        let cost = totalCost ?? 0

        let errors = FuelLogValidator.validate(
            odometer: odo,
            liters: lit,
            totalCost: cost,
            lastOdometer: odometerFloor
        )
        guard errors.isEmpty else {
            validationMessage = message(for: errors)
            return
        }

        if let log = fuelLog {
            log.date = date
            log.odometer = odo
            log.liters = lit
            log.totalCost = cost
            log.fuelType = fuelType
            log.isFullTank = isFullTank
            if ocrProcessed {
                log.ocrProcessed = true
                log.ocrConfidence = ocrConfidence
            }
        } else {
            let log = FuelLog(
                date: date,
                odometer: odo,
                liters: lit,
                totalCost: cost,
                fuelType: fuelType,
                isFullTank: isFullTank,
                motorcycle: motorcycle,
                ocrProcessed: ocrProcessed
            )
            log.ocrConfidence = ocrConfidence
            if let loc = location {
                log.latitude = loc.latitude
                log.longitude = loc.longitude
                log.city = loc.city
                log.state = loc.state
                log.country = loc.country
            }
            modelContext.insert(log)
        }
        // Avança o hodômetro da moto se este for mais recente.
        if odo > motorcycle.currentOdometer {
            motorcycle.currentOdometer = odo
        }
        do {
            try modelContext.save()
        } catch {
            validationMessage = "Não foi possível salvar. Tente novamente."
            return
        }
        Haptics.success()
        let ctx = modelContext
        Task { await SyncService.shared.pushAll(from: ctx) }
        dismiss()
    }

    private func message(for errors: [FuelLogValidationError]) -> String {
        errors.compactMap { err in
            switch err {
            case .odometerNotPositive: return "Hodômetro deve ser maior que zero."
            case .odometerBelowLast(let last):
                return "Hodômetro não pode ser menor que o último (\(AppFormat.km(last)))."
            case .litersNotPositive: return "Litros deve ser maior que zero."
            case .costNegative: return "Valor não pode ser negativo."
            }
        }.joined(separator: " ")
    }
}
