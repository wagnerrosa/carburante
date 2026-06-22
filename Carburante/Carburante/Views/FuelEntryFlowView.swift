//
//  FuelEntryFlowView.swift
//  Carburante
//
//  Registro de abastecimento em FOCO PROGRESSIVO (estilo PIX). Dois passos de
//  entrada + revisão:
//    1. Hodômetro — um número grande, teclado próprio, foto do painel (OCR) como
//       atalho opcional.
//    2. Valor + Litros — juntos, porque UMA foto do comprovante/bomba traz as
//       duas infos. A foto é o caminho em destaque ("o app é inteligente"):
//       lê e preenche os dois campos; digitar continua possível.
//    3. Revisão — confirma (preço/L, km/L), combustível + tanque cheio, e salva.
//
//  Usado só para registro NOVO. Edição continua no Form clássico
//  (`FuelLogFormView`) — editar log histórico não se beneficia do passo a passo
//  e relaxa a regra monotônica do hodômetro.
//
//  Reaproveita a lógica existente: `FuelLogValidator`, `LocationService`,
//  `OCRParser`/`TextRecognizer`, `AppFormat`, `Haptics`.
//

import SwiftUI
import SwiftData
import PhotosUI

struct FuelEntryFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let motorcycle: Motorcycle

    /// Passo atual. `fill` reúne valor + litros (uma foto traz os dois).
    private enum Step: Int, CaseIterable {
        case odometer, fill, review
    }
    @State private var step: Step = .odometer

    // Campos do FuelLog.
    @State private var date: Date = Date()
    @State private var odometer: Double?
    @State private var cost: Double?
    @State private var liters: Double?
    @State private var fuelType: FuelType = .gasolinaComum
    @State private var isFullTank: Bool = true

    // Local editável na revisão (pré-preenchido pela captura automática).
    @State private var editedCity: String = ""
    @State private var editedState: String = ""
    /// Data/hora originais auto-capturadas (abertura da tela) — referência para
    /// detectar edição manual. O local de referência vem de `location`.
    @State private var autoDate: Date = Date()

    // Foco dos campos (teclado nativo do iOS).
    private enum FillField { case odometer, cost, liters, city }
    @FocusState private var fillFocus: FillField?

    // Localização (background, best-effort).
    @State private var locationService = LocationService()
    @State private var location: LocationSnapshot?

    // OCR.
    @State private var ocrProcessed = false
    @State private var ocrConfidence: Double?
    @State private var odometerOCRStatus: OCRStatus?   // passo hodômetro
    @State private var receiptOCRStatus: OCRStatus?    // passo valor+litros
    @State private var isRecognizing = false

    /// Resultado de leitura por foto, exibido no feedback do passo.
    private struct OCRStatus {
        let text: String
        let icon: String
        let color: Color
    }

    // Apresentação de câmera/galeria. `photoTarget` decide o que a foto alimenta.
    private enum PhotoTarget { case odometer, receipt }
    @State private var photoTarget: PhotoTarget = .odometer
    @State private var showPhotoSource = false
    @State private var showCamera = false
    @State private var showGalleryPicker = false
    @State private var galleryItem: PhotosPickerItem?

    @State private var saveError: String?

    // MARK: - Derivados

    private var lastOdometer: Double {
        max(motorcycle.fuelLogs.map(\.odometer).max() ?? 0, motorcycle.currentOdometer)
    }

    private var odometerFloor: Double? {
        lastOdometer > 0 ? lastOdometer : nil
    }

    private var pricePerLiter: Double? {
        guard let l = liters, l > 0, let c = cost else { return nil }
        return c / l
    }

    private var estimatedKmPerLiter: Double? {
        guard isFullTank, let odo = odometer, let l = liters, l > 0,
              lastOdometer > 0, odo > lastOdometer else { return nil }
        return (odo - lastOdometer) / l
    }

    private var odometerDelta: Double? {
        guard let odo = odometer, odo > 0, lastOdometer > 0 else { return nil }
        return odo - lastOdometer
    }

    private var canSave: Bool {
        FuelLogValidator.validate(
            odometer: odometer ?? 0, liters: liters ?? 0,
            totalCost: cost ?? 0, lastOdometer: odometerFloor
        ).isEmpty
    }

    /// O passo atual está pronto para avançar?
    private var canAdvance: Bool {
        switch step {
        case .odometer:
            guard let odo = odometer, odo > 0 else { return false }
            if let floor = odometerFloor { return odo >= floor }
            return true
        case .fill:
            guard let c = cost, c > 0, let l = liters, l > 0 else { return false }
            return true
        case .review:
            return canSave
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                switch step {
                case .odometer: odometerScreen
                case .fill:     fillScreen
                case .review:   reviewScreen
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .tint(motorcycle.themeColor)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(step == .odometer ? "Cancelar" : "Voltar", action: back)
                }
                ToolbarItem(placement: .principal) {
                    if step != .review {
                        StepDots(total: 2, current: step.rawValue)
                    }
                }
                // Mesmo "ato" de fotografar nas duas telas de entrada: botão de
                // escanear no canto superior direito (espelha o Cancelar/Voltar
                // à esquerda). Some na revisão.
                ToolbarItem(placement: .primaryAction) {
                    if step != .review {
                        Button {
                            if isRecognizing { return }
                            photoTarget = (step == .odometer) ? .odometer : .receipt
                            showPhotoSource = true
                        } label: {
                            if isRecognizing {
                                ProgressView()
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "text.viewfinder")
                                    Text("Escanear")
                                }
                                .font(.body.weight(.medium))
                            }
                        }
                        .disabled(isRecognizing)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Concluir") { fillFocus = nil }
                }
            }
            .onAppear(perform: prefill)
            .task {
                let snap = await locationService.currentSnapshot()
                location = snap
                // Pré-preenche a cidade só se o usuário ainda não digitou nada.
                if let city = snap?.city, editedCity.isEmpty { editedCity = city }
                if let st = snap?.state, editedState.isEmpty { editedState = st }
            }
            .confirmationDialog(photoDialogTitle, isPresented: $showPhotoSource,
                                titleVisibility: .visible) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Tirar foto") { showCamera = true }
                }
                Button("Escolher da galeria") { showGalleryPicker = true }
            } message: {
                Text("O app lê os valores da foto — você só confere depois.")
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in Task { await processPhoto(image) } }
                    .ignoresSafeArea()
            }
            .photosPicker(isPresented: $showGalleryPicker, selection: $galleryItem, matching: .images)
            .onChange(of: galleryItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await processPhoto(image)
                    }
                    galleryItem = nil
                }
            }
        }
    }

    private var navTitle: String { step == .review ? "Revisar" : "Novo abastecimento" }

    private var photoDialogTitle: String {
        photoTarget == .odometer ? "Ler o hodômetro por foto" : "Ler o comprovante ou a bomba"
    }

    // MARK: - Cabeçalho

    private var header: some View {
        HStack(spacing: 10) {
            if let logo = motorcycle.logoAsset {
                BrandLogoTile(assetName: logo, size: 30)
            } else {
                IconTile(systemName: "motorcycle", tint: motorcycle.themeColor, size: 30)
            }
            Text(motorcycle.displayName)
                .font(.subheadline.weight(.semibold))
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Passo 1 — Hodômetro (teclado nativo, mesma estrutura do passo 2)

    private var odometerScreen: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Qual o hodômetro agora?")
                        .font(.title3.weight(.semibold))
                    Text("Digite, ou toque em Escanear para ler da foto.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let s = odometerOCRStatus {
                    feedbackLabel(s.text, icon: s.icon, color: s.color)
                        .padding(.horizontal, 4)
                }

                // Campo único com teclado nativo (igual valor+litros).
                HStack {
                    Text("Hodômetro").foregroundStyle(.secondary)
                    Spacer()
                    TextField("Hodômetro", value: $odometer, format: .number,
                              prompt: Text("0"))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .focused($fillFocus, equals: .odometer)
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: 160)
                    Text("km").foregroundStyle(.secondary).frame(width: 28, alignment: .leading)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                odometerFeedback.padding(.horizontal, 4)

                if lastOdometer > 0 {
                    Text("Último registro: \(AppFormat.km(lastOdometer))")
                        .font(.caption).foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            }
            .padding(20)
            .safeAreaInset(edge: .bottom) {
                advanceButton(title: "Próximo").background(.bar)
            }
        }
    }

    @ViewBuilder
    private var odometerFeedback: some View {
        if let floor = odometerFloor, let odo = odometer, odo > 0, odo < floor {
            feedbackLabel("Menor que o último (\(AppFormat.km(floor)))",
                          icon: "exclamationmark.triangle.fill", color: .orange)
        } else if let delta = odometerDelta, delta > 0 {
            feedbackLabel("+\(AppFormat.km(delta)) desde o último",
                          icon: "checkmark.circle.fill", color: .secondary)
        }
    }

    // MARK: - Passo 2 — Valor + Litros (foto em destaque, digitar opcional)

    private var fillScreen: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Mesma estrutura do passo 1: título + dica (a foto fica no
                // mesmo lugar nas duas telas — botão de escanear na navbar).
                VStack(alignment: .leading, spacing: 6) {
                    Text("Valor e litros")
                        .font(.title3.weight(.semibold))
                    Text("Digite, ou toque em Escanear para ler do comprovante.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let s = receiptOCRStatus {
                    feedbackLabel(s.text, icon: s.icon, color: s.color)
                        .padding(.horizontal, 4)
                }

                // Campos editáveis — preenchidos pela foto ou digitados.
                VStack(spacing: 0) {
                    fillRow(label: "Valor", unit: "R$", value: $cost,
                            field: .cost, prompt: "0,00")
                    Divider().padding(.leading, 16)
                    fillRow(label: "Litros", unit: "L", value: $liters,
                            field: .liters, prompt: "0,00")
                }
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                if let ppl = pricePerLiter {
                    feedbackLabel("≈ \(AppFormat.currencyPrecise(ppl)) por litro",
                                  icon: "fuelpump.fill", color: .secondary)
                        .padding(.horizontal, 4)
                }
            }
            .padding(20)
            .safeAreaInset(edge: .bottom) {
                advanceButton(title: "Revisar")
                    .background(.bar)
            }
        }
    }

    private func fillRow(label: String, unit: String, value: Binding<Double?>,
                         field: FillField, prompt: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            TextField(label, value: value, format: .number, prompt: Text(prompt))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .focused($fillFocus, equals: field)
                .font(.body.weight(.semibold))
                .frame(maxWidth: 140)
            Text(unit).foregroundStyle(.secondary).frame(width: 28, alignment: .leading)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture { fillFocus = field }
    }

    // MARK: - Passo 3 — Revisão

    private var reviewScreen: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let kmL = estimatedKmPerLiter {
                    VStack(spacing: 2) {
                        Text("Consumo deste tanque")
                            .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                        Text(AppFormat.kmPerLiter(kmL))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    fullToFullExplainer
                }

                VStack(spacing: 0) {
                    reviewRow("Hodômetro", value: odometer.map(AppFormat.km) ?? "—") { goTo(.odometer) }
                    Divider().padding(.leading, 16)
                    reviewRow("Valor", value: cost.map(AppFormat.currency) ?? "—") { goTo(.fill) }
                    Divider().padding(.leading, 16)
                    reviewRow("Litros",
                              value: liters.map(AppFormat.liters) ?? "—",
                              detail: pricePerLiter.map { "\(AppFormat.currencyPrecise($0))/L" }) { goTo(.fill) }
                }
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(spacing: 0) {
                    Picker("Combustível", selection: $fuelType) {
                        ForEach(FuelType.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 4)
                    Divider().padding(.leading, 16)
                    Toggle("Tanque cheio", isOn: $isFullTank)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                }
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                contextCard

                if let err = saveError {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote).foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: save) {
                    Text("Salvar abastecimento").font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canSave)
                .padding(.top, 4)
            }
            .padding(20)
        }
    }

    /// Explica o método full-to-full na revisão quando ainda não há km/l a
    /// mostrar (substitui o herói "Consumo deste tanque"). Conta os cheios já
    /// gravados MAIS este registro, se for cheio, para dizer quantos ainda
    /// faltam — e por que um abastecimento parcial não fecha a conta.
    @ViewBuilder
    private var fullToFullExplainer: some View {
        // Quantos cheios salvos já existem, mais este se for cheio.
        let savedFullTanks = motorcycle.fuelLogs.filter(\.isFullTank).count
        let afterThisSave = savedFullTanks + (isFullTank ? 1 : 0)
        // Faltam quantos para 2? (máximo 2, mínimo 0).
        let remaining = max(2 - afterThisSave, 0)

        VStack(spacing: 6) {
            Image(systemName: "fuelpump.circle.fill")
                .font(.title2)
                .foregroundStyle(.tint)
            Text(explainerTitle(remaining: remaining))
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(explainerSubtitle(remaining: remaining))
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16).padding(.horizontal, 12)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func explainerTitle(remaining: Int) -> String {
        if !isFullTank {
            return "Abastecimento parcial"
        }
        switch remaining {
        case 0:  return "Tudo pronto para medir"
        case 1:  return "Falta 1 abastecimento cheio"
        default: return "Faltam \(remaining) abastecimentos cheios"
        }
    }

    private func explainerSubtitle(remaining: Int) -> String {
        if !isFullTank {
            return "O consumo só é medido entre dois tanques cheios. Marque \"Tanque cheio\" quando completar o tanque."
        }
        switch remaining {
        case 0:  return "O km/l aparece no Resumo assim que você salvar."
        case 1:  return "O consumo é medido entre dois tanques cheios. No próximo cheio, seu km/l aparece."
        default: return "O consumo é medido entre dois tanques cheios. Encha o tanque ao abastecer para liberar o km/l."
        }
    }

    private func reviewRow(_ label: String, value: String, detail: String? = nil,
                           edit: @escaping () -> Void) -> some View {
        Button(action: edit) {
            HStack {
                Text(label).foregroundStyle(.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(value).font(.body.weight(.semibold))
                    if let detail {
                        Text(detail).font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16).padding(.vertical, 12).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Contexto do abastecimento na revisão: minimapa do local + data e local
    /// editáveis. Editar é permitido, mas fica REGISTRADO (flags de proveniência)
    /// — base de auditoria anti-burla dos desafios Iron Butt.
    private var contextCard: some View {
        VStack(spacing: 0) {
            if let lat = location?.latitude, let lon = location?.longitude {
                FuelLocationMap(latitude: lat, longitude: lon,
                                label: editedCity.isEmpty ? "Abastecimento" : editedCity,
                                height: 130)
                    .padding(.horizontal, 12).padding(.top, 12)
            }

            DatePicker("Data", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .padding(.horizontal, 16).padding(.vertical, 8)
            Divider().padding(.leading, 16)

            HStack {
                Text("Cidade").foregroundStyle(.secondary)
                Spacer()
                TextField("Cidade", text: $editedCity, prompt: Text("Onde abasteceu"))
                    .multilineTextAlignment(.trailing)
                    .focused($fillFocus, equals: .city)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)

            if dateWasEdited || locationWasEdited {
                Divider().padding(.leading, 16)
                Label(editNote, systemImage: "pencil.circle")
                    .font(.caption2).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.vertical, 8)
            }
        }
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// Detecta edição manual da data (≥1 min de diferença do auto-capturado).
    private var dateWasEdited: Bool {
        abs(date.timeIntervalSince(autoDate)) > 60
    }

    /// Detecta edição manual do local (cidade diverge da auto-capturada).
    private var locationWasEdited: Bool {
        editedCity.trimmingCharacters(in: .whitespaces) != (location?.city ?? "")
    }

    /// Observação neutra (não acusatória) de que o contexto foi ajustado à mão.
    private var editNote: String {
        switch (dateWasEdited, locationWasEdited) {
        case (true, true):  return "Data e local ajustados manualmente"
        case (true, false): return "Data ajustada manualmente"
        default:            return "Local ajustado manualmente"
        }
    }

    // MARK: - Componentes compartilhados

    private func feedbackLabel(_ text: String, icon: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.footnote.weight(.medium))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func advanceButton(title: String) -> some View {
        Button(action: advance) {
            Text(title).font(.headline).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!canAdvance)
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 12)
    }

    // MARK: - Navegação

    private func advance() {
        guard canAdvance else { return }
        Haptics.selection()
        fillFocus = nil
        switch step {
        case .odometer: goTo(.fill)
        case .fill:     goTo(.review)
        case .review:   break
        }
    }

    private func back() {
        fillFocus = nil
        switch step {
        case .odometer: dismiss()
        case .fill:     goTo(.odometer)
        case .review:   goTo(.fill)
        }
    }

    private func goTo(_ target: Step) {
        step = target
        saveError = nil
    }

    // MARK: - Prefill / OCR / Save

    private func prefill() {
        if let last = motorcycle.latestFuelLog { fuelType = last.fuelType }
    }

    private func processPhoto(_ image: UIImage) async {
        guard let cg = image.cgImage else { return }
        isRecognizing = true
        defer { isRecognizing = false }

        switch photoTarget {
        case .odometer:
            odometerOCRStatus = nil
            do {
                let r = try await TextRecognizer.recognize(in: cg)
                if let odo = OCRParser.parseOdometer(r.lines) {
                    odometer = odo
                    ocrProcessed = true
                    ocrConfidence = r.confidence
                    odometerOCRStatus = OCRStatus(text: "Hodômetro lido — confira",
                                                  icon: "checkmark.circle.fill", color: .secondary)
                    Haptics.selection()
                } else {
                    odometerOCRStatus = OCRStatus(text: "Não consegui ler — digite o hodômetro",
                                                  icon: "exclamationmark.triangle.fill", color: .orange)
                    Haptics.warning()
                }
            } catch {
                odometerOCRStatus = OCRStatus(text: "Falha ao ler a foto — digite o hodômetro",
                                              icon: "exclamationmark.triangle.fill", color: .orange)
                Haptics.warning()
            }
        case .receipt:
            receiptOCRStatus = nil
            do {
                let r = try await TextRecognizer.recognize(in: cg)
                let result = OCRParser.parseFuelReceipt(r.lines)
                if let l = result.liters { liters = l }
                if let c = result.totalCost { cost = c }
                if let f = result.fuelType { fuelType = f }
                ocrProcessed = true
                ocrConfidence = r.confidence
                let got = [result.totalCost != nil ? "valor" : nil,
                           result.liters != nil ? "litros" : nil].compactMap { $0 }
                if got.isEmpty {
                    receiptOCRStatus = OCRStatus(text: "Não consegui ler — digite os valores",
                                                 icon: "exclamationmark.triangle.fill", color: .orange)
                    Haptics.warning()
                } else {
                    receiptOCRStatus = OCRStatus(text: "Lido \(got.joined(separator: " e ")) — confira",
                                                 icon: "checkmark.circle.fill", color: .secondary)
                    Haptics.selection()
                }
            } catch {
                receiptOCRStatus = OCRStatus(text: "Falha ao ler a foto — digite os valores",
                                             icon: "exclamationmark.triangle.fill", color: .orange)
                Haptics.warning()
            }
        }
    }

    private func save() {
        let odo = odometer ?? 0, lit = liters ?? 0, c = cost ?? 0
        guard FuelLogValidator.validate(
            odometer: odo, liters: lit, totalCost: c, lastOdometer: odometerFloor
        ).isEmpty else {
            saveError = "Verifique os valores antes de salvar."
            return
        }

        let log = FuelLog(
            date: date, odometer: odo, liters: lit, totalCost: c,
            fuelType: fuelType, isFullTank: isFullTank,
            motorcycle: motorcycle, ocrProcessed: ocrProcessed
        )
        log.ocrConfidence = ocrConfidence
        // Coordenadas GPS são a verdade (não editáveis); cidade/estado são o
        // rótulo, que o usuário pode corrigir na revisão.
        log.latitude = location?.latitude
        log.longitude = location?.longitude
        log.city = editedCity.isEmpty ? location?.city : editedCity
        log.state = editedState.isEmpty ? location?.state : editedState
        log.country = location?.country
        // Proveniência: registra se o contexto auto-capturado foi mexido à mão.
        log.dateWasEdited = dateWasEdited
        log.locationWasEdited = locationWasEdited
        modelContext.insert(log)
        motorcycle.reconcileOdometer(latestEntry: odo)
        do {
            try modelContext.save()
        } catch {
            saveError = "Não foi possível salvar. Tente novamente."
            return
        }
        Haptics.success()
        let ctx = modelContext
        Task { await SyncService.shared.pushAll(from: ctx) }
        // Reagenda os lembretes de ausência a partir do abastecimento mais
        // recente (a data é Sendable; calculada aqui no main actor).
        let lastFuelDate = motorcycle.fuelLogs.map(\.date).max()
        let oilStatus = motorcycle.oilChangeStatus()
        Task {
            await NotificationService.shared.rescheduleAbsenceReminders(lastFuelDate: lastFuelDate)
            await NotificationService.shared.rescheduleOilChange(status: oilStatus)
        }
        dismiss()
    }
}

private extension LocationSnapshot {
    var placeLabel: String? {
        let parts = [city, state].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}

// MARK: - Indicador de passo

/// Pontinhos no centro da navbar indicando o passo de entrada atual (discreto;
/// orientação, não navegação). A revisão não tem dot (é confirmação).
private struct StepDots: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i == current ? Color.accentColor : Color(.tertiaryLabel))
                    .frame(width: 6, height: 6)
            }
        }
    }
}
