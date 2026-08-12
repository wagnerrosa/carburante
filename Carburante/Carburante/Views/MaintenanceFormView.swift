//
//  MaintenanceFormView.swift
//  Carburante
//
//  Cadastro e edição de manutenção. Form nativo.
//

import SwiftUI
import SwiftData

/// Escolha de posição no form (inclui "Ambos", que NÃO é persistido: ao salvar
/// vira dois logs — um dianteiro, um traseiro). Só aparece quando o tipo é Pneus.
enum TireSelection: String, CaseIterable, Identifiable {
    case dianteiro = "Dianteiro"
    case traseiro = "Traseiro"
    case ambos = "Ambos"

    var id: String { rawValue }

    /// Posições concretas a gravar. "Ambos" → dois logs.
    var positions: [TirePosition] {
        switch self {
        case .dianteiro: return [.dianteiro]
        case .traseiro: return [.traseiro]
        case .ambos: return [.dianteiro, .traseiro]
        }
    }

    init(position: TirePosition?) {
        switch position {
        case .traseiro: self = .traseiro
        default: self = .dianteiro
        }
    }
}

struct MaintenanceFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let motorcycle: Motorcycle
    /// Nil = nova manutenção. Não-nil = edição.
    var maintenanceLog: MaintenanceLog?
    /// Tipo inicial p/ nova manutenção (ex.: tocar numa linha "Programadas").
    /// Ignorado em edição.
    var initialType: MaintenanceType?
    /// Posição de pneu inicial p/ nova manutenção (linha "Programadas" de pneu).
    /// Ignorada em edição e em tipos que não são pneu.
    var initialTirePosition: TirePosition?

    @State private var date: Date = Date()
    @State private var type: MaintenanceType = .oleo
    @State private var mileage: Double?
    @State private var cost: Double?
    @State private var intervalKm: Double? = MaintenanceType.oleo.defaultIntervalKm
    @State private var intervalMonths: Int? = MaintenanceType.oleo.defaultIntervalMonths
    @State private var notes: String = ""
    /// Itens marcados numa Revisão Geral (combo). Cada um vira um log-filho que
    /// reinicia o contador do seu tipo. Fase B — ver PLAN/manutencao-programada.md.
    @State private var revisaoItems: Set<MaintenanceType> = []
    /// Posição do pneu numa manutenção avulsa de pneu. "Ambos" (só em criação)
    /// grava dois logs.
    @State private var tireSelection: TireSelection = .dianteiro
    /// Posição do pneu quando "Pneus" está marcado numa Revisão Geral.
    @State private var revisaoTireSelection: TireSelection = .ambos
    @State private var saveError: String?
    /// Evita que o `onChange(of: type)` (disparado ao carregar) sobrescreva os
    /// valores carregados/iniciais com os defaults do tipo.
    @State private var didLoad = false
    @FocusState private var fieldFocused: Bool

    private var isEditing: Bool { maintenanceLog != nil }

    /// Opções do seletor de posição: "Ambos" só faz sentido criando (dois logs);
    /// editando, uma linha é sempre uma posição.
    private var tirePositionOptions: [TireSelection] {
        isEditing ? [.dianteiro, .traseiro] : TireSelection.allCases
    }

    private var mileagePrompt: String {
        motorcycle.currentOdometer > 0 ? "Atual: \(AppFormat.odometer(motorcycle.currentOdometer))" : "Hodômetro"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Passado liberado (retro-registro é bem-vindo); futuro não —
                    // manutenção é registro do que já foi feito. Um log futuro
                    // criado antes deste limite continua editável (max com a
                    // data dele, senão o picker clamparia a data sem o usuário pedir).
                    DatePicker("Data", selection: $date,
                               in: ...max(Date(), maintenanceLog?.date ?? .distantPast),
                               displayedComponents: [.date])
                    Picker("Tipo", selection: $type) {
                        ForEach(MaintenanceType.allCases) { t in
                            Label(t.rawValue, systemImage: t.icon).tag(t)
                        }
                    }
                    HStack {
                        TextField("Hodômetro", value: $mileage, format: .number, prompt: Text(mileagePrompt))
                            .keyboardType(.decimalPad)
                            .focused($fieldFocused)
                        Text("km").foregroundStyle(.secondary)
                    }
                    HStack {
                        TextField("Custo", value: $cost, format: .number, prompt: Text("Custo"))
                            .keyboardType(.decimalPad)
                            .focused($fieldFocused)
                        Text("R$").foregroundStyle(.secondary)
                    }
                } footer: {
                    if let backfillWarning {
                        Label(backfillWarning, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                // Pneus: dianteiro e traseiro têm contadores próprios (trocam em
                // momentos diferentes). "Ambos" só na criação — editar um registro
                // é sempre uma posição só (não dá para dividir uma linha em duas).
                if type == .pneus {
                    Section {
                        Picker("Posição", selection: $tireSelection) {
                            ForEach(tirePositionOptions) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                    } footer: {
                        Text(isEditing
                             ? "Dianteiro e traseiro são acompanhados separadamente."
                             : "Dianteiro e traseiro têm contadores próprios. \"Ambos\" registra os dois de uma vez.")
                    }
                }

                // Revisão Geral não tem contador próprio (é ação que reinicia os
                // itens incluídos, não meta agendável) → sem seção de intervalo.
                if type != .revisao {
                    Section {
                        HStack {
                            Text("A cada")
                            TextField(
                                "Intervalo",
                                value: $intervalKm,
                                format: .number,
                                prompt: Text(type.defaultIntervalKm.map(AppFormat.odometer) ?? "—")
                            )
                            .keyboardType(.numberPad)
                            .focused($fieldFocused)
                            .multilineTextAlignment(.trailing)
                            Text("km").foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("A cada")
                            TextField(
                                "Intervalo",
                                value: $intervalMonths,
                                format: .number,
                                prompt: Text(type.defaultIntervalMonths.map { "\($0)" } ?? "—")
                            )
                            .keyboardType(.numberPad)
                            .focused($fieldFocused)
                            .multilineTextAlignment(.trailing)
                            Text("meses").foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Próxima manutenção")
                    } footer: {
                        Text("A cada quanto repetir esta manutenção — por km, por tempo, ou ambos (vence pelo que vier primeiro). Pré-preenchido com uma sugestão; ajuste conforme o manual da sua moto.")
                    }
                }

                if type == .revisao {
                    Section {
                        ForEach(MaintenanceType.revisaoComboTypes) { item in
                            Toggle(isOn: revisaoBinding(for: item)) {
                                Label(item.rawValue, systemImage: item.icon)
                            }
                            // Pneu numa revisão pode ter sido só um eixo (ex.: só
                            // o traseiro) → escolhe a posição a reiniciar.
                            if item == .pneus, revisaoItems.contains(.pneus) {
                                Picker("Posição", selection: $revisaoTireSelection) {
                                    ForEach(TireSelection.allCases) { option in
                                        Text(option.rawValue).tag(option)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                    } header: {
                        Text("Itens executados")
                    } footer: {
                        // Revisão sem itens não reinicia contador nenhum nem
                        // aparece em Programadas (não é agendável) → o serviço se
                        // perderia. Exige ≥1 item (ver canSave).
                        Text(revisaoItems.isEmpty
                             ? "Marque ao menos um item executado."
                             : "Marque o que foi feito nesta revisão — cada item reinicia o próprio contador, na mesma data e km. O custo total fica na revisão.")
                        .foregroundStyle(revisaoItems.isEmpty ? .orange : .secondary)
                    }
                }

                Section("Observações") {
                    TextField("Opcional", text: $notes, axis: .vertical)
                        .lineLimit(1...6)
                }

                if let saveError {
                    Section {
                        Label(saveError, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isEditing ? "Editar Manutenção" : "Nova Manutenção")
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
            .onAppear(perform: load)
            // Trocar o tipo repõe os intervalos com os defaults do novo tipo
            // (só após o carregamento inicial, p/ não apagar valores carregados).
            .onChange(of: type) { _, newType in
                guard didLoad else { return }
                intervalKm = newType.defaultIntervalKm
                intervalMonths = newType.defaultIntervalMonths
            }
        }
    }

    private func load() {
        defer { didLoad = true }
        if let log = maintenanceLog {
            date = log.date
            type = log.type
            mileage = log.mileage
            cost = log.cost
            intervalKm = log.effectiveIntervalKm
            intervalMonths = log.effectiveIntervalMonths
            notes = log.notes
            if log.type == .pneus {
                tireSelection = TireSelection(position: log.tirePosition)
            }
            // Pré-marca os itens já incluídos nesta revisão (logs-filhos).
            revisaoItems = Set(log.children.map(\.type))
            // Posição do pneu já incluído na revisão (se houver): se os dois
            // filhos existem = Ambos; senão a posição do único.
            let tireChildren = log.children.filter { $0.type == .pneus }
            if tireChildren.count >= 2 {
                revisaoTireSelection = .ambos
            } else if let only = tireChildren.first {
                revisaoTireSelection = TireSelection(position: only.tirePosition)
            }
        } else if let initialType {
            type = initialType
            intervalKm = initialType.defaultIntervalKm
            intervalMonths = initialType.defaultIntervalMonths
            if initialType == .pneus, let initialTirePosition {
                tireSelection = TireSelection(position: initialTirePosition)
            }
        }
    }

    private func revisaoBinding(for item: MaintenanceType) -> Binding<Bool> {
        Binding(
            get: { revisaoItems.contains(item) },
            set: { isOn in
                if isOn { revisaoItems.insert(item) } else { revisaoItems.remove(item) }
            }
        )
    }

    /// Âncoras atuais de próximo vencimento que ESTE save pode substituir:
    /// o tipo do form; para pneus, cada posição selecionada ("Ambos" = as duas);
    /// para Revisão Geral, cada item marcado (os logs-filhos reiniciam esses
    /// contadores, não o da revisão em si).
    private var backfillAnchors: [MaintenanceLog] {
        switch type {
        case .pneus:
            return tireSelection.positions.compactMap {
                motorcycle.lastService(of: .pneus, position: $0)
            }
        case .revisao:
            return revisaoItems.flatMap { item -> [MaintenanceLog] in
                if item == .pneus {
                    return revisaoTireSelection.positions.compactMap {
                        motorcycle.lastService(of: .pneus, position: $0)
                    }
                }
                return motorcycle.lastService(of: item).map { [$0] } ?? []
            }
        default:
            return motorcycle.lastService(of: type).map { [$0] } ?? []
        }
    }

    /// Aviso de retro-registro (nunca bloqueia o Salvar): km menor que alguma
    /// âncora com data igual ou mais nova → este registro viraria a âncora do
    /// próximo vencimento e "voltaria" o contador. Registro antigo é bem-vindo —
    /// só precisa da data certa. Comparação por dia (a hora do form é arbitrária).
    private var backfillWarning: String? {
        guard maintenanceLog == nil, let km = mileage, km > 0 else { return nil }
        let calendar = Calendar.current
        let regressed = backfillAnchors.filter {
            km < $0.mileage && calendar.startOfDay(for: date) >= calendar.startOfDay(for: $0.date)
        }
        guard let worst = regressed.max(by: { $0.mileage < $1.mileage }) else { return nil }
        return "Km menor que a última (\(AppFormat.km(worst.mileage))). Se é um registro antigo, ajuste a data — senão o próximo vencimento volta para trás."
    }

    private var canSave: Bool {
        guard (mileage ?? 0) > 0 else { return false }
        // Revisão Geral precisa de ≥1 item: sem item não reinicia contador nem
        // aparece em Programadas (não é agendável) → o serviço se perderia.
        if type == .revisao, revisaoItems.isEmpty { return false }
        return true
    }

    private func save() {
        let km = mileage ?? 0
        guard km > 0 else { return }
        let c = cost ?? 0
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        // Em branco → nil → cai no padrão do tipo (effectiveInterval*). Valores
        // > 0 personalizam este registro e os seguintes do mesmo tipo.
        let ik = (intervalKm ?? 0) > 0 ? intervalKm : nil
        let im = (intervalMonths ?? 0) > 0 ? intervalMonths : nil

        let parent: MaintenanceLog
        let wasEditing = maintenanceLog != nil
        // Conta antes do insert: 1ª manutenção da moto?
        let isFirst = !wasEditing && motorcycle.activeMaintenanceLogs.isEmpty
        if let log = maintenanceLog {
            log.date = date
            log.type = type
            log.mileage = km
            log.cost = c
            log.notes = trimmedNotes
            log.intervalKm = ik
            log.intervalMonths = im
            // Editar sempre é uma posição só (o seletor não oferece "Ambos").
            log.tirePosition = type == .pneus ? tireSelection.positions.first : nil
            // Soft Revision: registra a edição (revision++ / updatedAt p/ o sync).
            log.markUpdated()
            parent = log
        } else if type == .pneus {
            // Criar pneu: "Ambos" grava dois logs independentes (contadores
            // próprios). Custo total fica no 1º p/ não contar em dobro.
            let positions = tireSelection.positions
            var first: MaintenanceLog?
            for (index, position) in positions.enumerated() {
                let log = MaintenanceLog(
                    date: date, mileage: km, cost: index == 0 ? c : 0,
                    notes: trimmedNotes, type: .pneus, tirePosition: position,
                    intervalKm: ik, intervalMonths: im, motorcycle: motorcycle
                )
                modelContext.insert(log)
                if first == nil { first = log }
            }
            parent = first!
        } else {
            let log = MaintenanceLog(
                date: date,
                mileage: km,
                cost: c,
                notes: trimmedNotes,
                type: type,
                intervalKm: ik,
                intervalMonths: im,
                motorcycle: motorcycle
            )
            modelContext.insert(log)
            parent = log
        }
        // Combo Revisão Geral: sincroniza os logs-filhos com a seleção. Se o tipo
        // deixou de ser revisão (edição), remove os filhos órfãos.
        if type == .revisao {
            syncRevisaoChildren(parent: parent)
        } else {
            for child in parent.children { modelContext.delete(child) }
        }
        do {
            try modelContext.save()
        } catch {
            saveError = "Não foi possível salvar. Tente novamente."
            return
        }
        Haptics.success()

        // Analytics — só na criação (sem evento _updated para manutenção no v1).
        if !wasEditing {
            Analytics.maintenanceCreated(
                type: type,
                isFirst: isFirst,
                fromScheduledPrompt: initialType != nil,
                customInterval: ik != nil || im != nil,
                revisaoItemCount: type == .revisao ? revisaoItems.count : nil
            )
            // Registrar a partir do prompt agendado = adoção da manutenção programada.
            if initialType != nil, AdoptionTracker.markAndCheck(.scheduledMaintenance) {
                Analytics.featureAdopted(.scheduledMaintenance)
            }
        }

        let ctx = modelContext
        Task { await SyncService.shared.pushAll(from: ctx) }
        // Registrar/editar uma manutenção reinicia o intervalo do tipo →
        // recalcula os lembretes de todos os tipos.
        let statuses = motorcycle.maintenanceStatuses()
        Analytics.evaluateOilOverdue(statuses: statuses, bikeID: motorcycle.id)
        Task { await NotificationService.shared.rescheduleMaintenance(statuses: statuses) }
        dismiss()
    }

    /// Cria/atualiza/remove os logs-filhos de uma Revisão Geral conforme os itens
    /// marcados. Cada filho herda a data e o km do pai (reinicia o contador do
    /// tipo), custo 0 (o custo da visita fica no pai → sem dupla contagem) e
    /// intervalos nil (cai no padrão do tipo). Pneus é tratado à parte: cada
    /// posição (dianteiro/traseiro) é um filho independente.
    private func syncRevisaoChildren(parent: MaintenanceLog) {
        let existing = parent.children
        // Itens não-pneu: plano genérico por tipo.
        let nonTireSelected = revisaoItems.subtracting([.pneus])
        let nonTireExisting = Set(existing.filter { $0.type != .pneus }.map(\.type))
        let plan = RevisaoCombo.plan(selected: nonTireSelected, existing: nonTireExisting)
        for item in plan.toCreate {
            let child = MaintenanceLog(
                date: parent.date, mileage: parent.mileage, cost: 0, notes: "",
                type: item, intervalKm: nil, intervalMonths: nil,
                partOfMaintenanceID: parent.id, motorcycle: motorcycle
            )
            modelContext.insert(child)
        }
        for item in plan.toKeep {
            if let child = existing.first(where: { $0.type == item }) {
                child.date = parent.date
                child.mileage = parent.mileage
            }
        }
        for item in plan.toDelete {
            if let child = existing.first(where: { $0.type == item }) {
                modelContext.delete(child)
            }
        }
        syncRevisaoTireChildren(parent: parent, existing: existing)
    }

    /// Sincroniza os filhos-pneu de uma revisão por posição: cria os que faltam,
    /// atualiza data/km dos que ficam, remove os desmarcados. Filho-pneu antigo
    /// sem posição (nil) é migrado para a 1ª posição desejada em vez de duplicar.
    private func syncRevisaoTireChildren(parent: MaintenanceLog, existing: [MaintenanceLog]) {
        let tireChildren = existing.filter { $0.type == .pneus }
        let wanted: Set<TirePosition> = revisaoItems.contains(.pneus)
            ? Set(revisaoTireSelection.positions) : []

        // Reaproveita um filho legado sem posição p/ evitar duplicata na migração.
        if let legacy = tireChildren.first(where: { $0.tirePosition == nil }),
           let target = wanted.first(where: { pos in !tireChildren.contains { $0.tirePosition == pos } }) {
            legacy.tirePosition = target
        }
        let byPosition = Dictionary(
            grouping: parent.children.filter { $0.type == .pneus },
            by: { $0.tirePosition }
        )
        for position in TirePosition.allCases {
            let current = byPosition[position]?.first
            if wanted.contains(position) {
                if let child = current {
                    child.date = parent.date
                    child.mileage = parent.mileage
                } else {
                    let child = MaintenanceLog(
                        date: parent.date, mileage: parent.mileage, cost: 0, notes: "",
                        type: .pneus, tirePosition: position, intervalKm: nil,
                        intervalMonths: nil, partOfMaintenanceID: parent.id,
                        motorcycle: motorcycle
                    )
                    modelContext.insert(child)
                }
            } else if let child = current {
                modelContext.delete(child)
            }
        }
        // Remove filho-pneu sem posição que não foi reaproveitado (desmarcado).
        for child in parent.children where child.type == .pneus && child.tirePosition == nil {
            modelContext.delete(child)
        }
    }
}
