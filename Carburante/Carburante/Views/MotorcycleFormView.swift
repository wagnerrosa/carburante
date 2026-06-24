//
//  MotorcycleFormView.swift
//  Carburante
//
//  Cadastro e edição de moto. Form nativo (HIG). Sem libs externas.
//

import SwiftUI
import SwiftData

struct MotorcycleFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Nil = cadastro novo. Não-nil = edição.
    var motorcycle: Motorcycle?

    /// Marca selecionada no Picker. "Outra…" revela o campo livre `make`.
    @State private var selectedMake: String = MotorcycleMake.catalog.first ?? ""
    /// Marca efetiva persistida. Espelha o Picker, exceto quando "Outra…" → texto livre.
    @State private var make: String = ""
    @State private var model: String = ""
    @State private var year: Int = Calendar.current.component(.year, from: Date())
    @State private var country: String = "Brasil"
    @State private var currentOdometer: Double = 0
    /// Opcional — nil = "Não informado". Pode ser completado depois.
    @State private var category: MotorcycleCategory?
    @State private var displacementCC: Int?
    @State private var saveError: String?
    @FocusState private var odometerFocused: Bool
    @FocusState private var displacementFocused: Bool

    private var isEditing: Bool { motorcycle != nil }

    /// "Outra…" → usa o texto livre; senão a própria marca do Picker.
    private var effectiveMake: String {
        selectedMake == MotorcycleMake.other ? make : selectedMake
    }

    private var isOther: Bool { selectedMake == MotorcycleMake.other }

    /// Tema de pré-visualização — reflete a marca escolhida no Picker, antes de
    /// salvar. "Outra…"/texto livre cai no padrão (azul) já que não há marca
    /// definida. Tinge o form inteiro ao vivo → efeito de identidade imediato.
    private var previewTheme: Color {
        BrandTheme.color(make: effectiveMake)
    }

    /// Asset do logo da marca selecionada (nil = "Outra…"/fora do catálogo).
    private var selectedLogo: String? {
        BrandTheme.logoAsset(make: effectiveMake)
    }

    /// Título contextual: "Nova {Marca}" quando uma marca do catálogo está
    /// escolhida (ex.: "Nova Kawasaki"); senão o genérico. Edição usa "Editar".
    private var titleText: String {
        if isEditing { return "Editar Moto" }
        let mk = effectiveMake.trimmingCharacters(in: .whitespaces)
        return MotorcycleMake.isKnown(mk) ? "Nova \(mk)" : "Nova Moto"
    }

    /// Mínimo para registrar: marca + modelo. Categoria, cilindrada e país são
    /// opcionais (completáveis depois) → menos atrito até o 1º abastecimento.
    private var canSave: Bool {
        !effectiveMake.trimmingCharacters(in: .whitespaces).isEmpty
            && !model.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private let yearRange = Array(1950...Calendar.current.component(.year, from: Date()) + 1).reversed()

    var body: some View {
        NavigationStack {
            Form {
                Section("Moto") {
                    // Logo da marca fica só no título do header (não no Picker).
                    // O valor do Picker usa accentColor, que NÃO segue o `.tint()`
                    // do ambiente → tint explícito por Picker p/ pegar a cor da marca.
                    Picker("Marca", selection: $selectedMake) {
                        ForEach(MotorcycleMake.catalog, id: \.self) { mk in
                            Text(mk).tag(mk)
                        }
                    }
                    .tint(previewTheme)
                    // O `.tint` do Picker resolve uma vez e não re-avalia quando a
                    // marca muda → o valor ficava na cor da 1ª marca (Honda/vermelho).
                    // `.id` força recriar o Picker p/ pegar o tint novo.
                    .id("marca-\(effectiveMake)")
                    if isOther {
                        TextField("Nome da marca", text: $make)
                            .textInputAutocapitalization(.words)
                    }
                    TextField("Modelo", text: $model)
                        .textInputAutocapitalization(.words)
                    Picker("Ano", selection: $year) {
                        ForEach(yearRange, id: \.self) { y in
                            Text(String(y)).tag(y)
                        }
                    }
                    .tint(previewTheme)
                    .id("ano-\(effectiveMake)")
                }

                Section {
                    Picker("Categoria", selection: $category) {
                        Text("Não informado").tag(MotorcycleCategory?.none)
                        ForEach(MotorcycleCategory.allCases) { cat in
                            Text(cat.label).tag(MotorcycleCategory?.some(cat))
                        }
                    }
                    .tint(previewTheme)
                    .id("cat-\(effectiveMake)")
                    HStack {
                        TextField("Cilindrada", value: $displacementCC, format: .number)
                            .keyboardType(.numberPad)
                            .focused($displacementFocused)
                        Text("cc")
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("País") {
                        TextField("País", text: $country)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.words)
                    }
                } header: {
                    Text("Detalhes (opcional)")
                } footer: {
                    Text("Categoria e cilindrada habilitam a comparação de consumo com motos parecidas. Pode completar depois.")
                }

                Section("Hodômetro") {
                    HStack {
                        TextField("Quilometragem atual", value: $currentOdometer, format: .number)
                            .keyboardType(.decimalPad)
                            .focused($odometerFocused)
                        Text("km")
                            .foregroundStyle(.secondary)
                    }
                }

                if let saveError {
                    Section {
                        Label(saveError, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(titleText)  // VoiceOver / fallback
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Título custom: logo da marca + "Nova {Marca}". Anima a troca.
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        if let logo = selectedLogo {
                            BrandLogoTile(assetName: logo, size: 26)
                                .transition(.scale.combined(with: .opacity))
                                .id(logo)
                        }
                        Text(titleText)
                            .font(.headline)
                            .contentTransition(.numericText())
                            .id(titleText)
                            .transition(.opacity)
                    }
                    // Anima só o header (logo + texto) na troca de marca; o tint
                    // do resto da tela troca instantâneo (sem blend de cor).
                    .animation(.smooth(duration: 0.3), value: selectedMake)
                    .animation(.smooth(duration: 0.3), value: make)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { save() }
                        .disabled(!canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Concluir") {
                        odometerFocused = false
                        displacementFocused = false
                    }
                }
            }
            .onAppear(perform: loadIfEditing)
            .onChange(of: selectedMake) { Haptics.selection() }
        }
        // Tema ao vivo no NavigationStack inteiro: form + barra de navegação
        // (Cancelar/Salvar/título/Pickers) assumem a cor da marca — identidade
        // total antes de salvar. Tint aplicado SEM animar a cor: animar `tint`
        // mistura cor-velha→cor-nova quadro a quadro, e o valor dos Pickers fica
        // num tom intermediário (parecia "vermelho preso"). Snap instantâneo do
        // tint; só o header (logo + texto) anima a troca.
        .tint(previewTheme)
    }

    private func loadIfEditing() {
        guard let m = motorcycle else { return }
        if MotorcycleMake.isKnown(m.make) {
            selectedMake = m.make
            make = m.make
        } else {
            // Marca fora do catálogo → começa em "Outra…" com o texto preenchido.
            selectedMake = MotorcycleMake.other
            make = m.make
        }
        model = m.model
        year = m.year
        country = m.country
        currentOdometer = m.currentOdometer
        category = m.categoryEnum
        displacementCC = m.displacementCC
    }

    private func save() {
        let trimmedMake = effectiveMake.trimmingCharacters(in: .whitespaces)
        let trimmedModel = model.trimmingCharacters(in: .whitespaces)
        let trimmedCountry = country.trimmingCharacters(in: .whitespaces)

        if let m = motorcycle {
            m.make = trimmedMake
            m.model = trimmedModel
            m.year = year
            m.country = trimmedCountry
            // O hodômetro do form é a leitura manual (baseline); reconcilia o
            // efetivo com os abastecimentos existentes (nunca abaixo deles).
            m.odometerBaseline = currentOdometer
            m.reconcileOdometer()
            m.categoryEnum = category
            m.displacementCC = displacementCC
        } else {
            let new = Motorcycle(
                make: trimmedMake,
                model: trimmedModel,
                year: year,
                country: trimmedCountry,
                currentOdometer: currentOdometer,
                category: category?.rawValue,
                displacementCC: displacementCC
            )
            modelContext.insert(new)
        }

        do {
            try modelContext.save()
        } catch {
            saveError = "Não foi possível salvar. Tente novamente."
            return
        }
        Haptics.success()
        let ctx = modelContext
        Task { await SyncService.shared.pushAll(from: ctx) }
        dismiss()
    }
}

#Preview("Nova") {
    MotorcycleFormView()
        .modelContainer(for: Motorcycle.self, inMemory: true)
}
