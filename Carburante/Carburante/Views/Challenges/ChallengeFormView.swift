//
//  ChallengeFormView.swift
//  Carburante
//
//  Novo desafio: nome, prazo em 1 toque (1 semana | 1 mês | Até…), capa.
//  Métrica fixa = km rodados (PLAN/desafios.md §Telas). A capa já sai daqui
//  recortada e reduzida (`ChallengeCover.jpeg`): o que a pessoa vê é o que sobe.
//

import SwiftUI
import PhotosUI

struct ChallengeFormView: View {
    var prefillName = ""
    /// Cria no servidor (com a capa em JPEG, ou nil = capa padrão). D0 passa
    /// um que não faz nada.
    var onCreate: (_ name: String, _ period: ChallengePeriod, _ pilotName: String,
                   _ cover: Data?) async throws -> Void = { _, _, _, _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var pilotName = ChallengeName.suggestedPilotName()
    @State private var duration: ChallengeDuration = .month
    @State private var startDate = Calendar.current.startOfDay(for: Date())
    @State private var untilDate = Calendar.current.date(byAdding: .day, value: 14, to: Date())!
    @State private var coverItem: PhotosPickerItem?
    /// Capa pronta para subir e a imagem dela para a prévia.
    @State private var cover: (jpeg: Data, image: UIImage)?
    @State private var isPreparingCover = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var nameFocused: Bool

    private var calendar: Calendar { .current }
    private var today: Date { calendar.startOfDay(for: Date()) }

    private var period: ChallengePeriod {
        duration.period(from: startDate, until: untilDate)
    }

    private var cleanName: String? {
        ChallengeName.cleaned(name, maxLength: ChallengeName.challengeMaxLength)
    }

    private var cleanPilotName: String? {
        ChallengeName.cleaned(pilotName, maxLength: ChallengeName.pilotMaxLength)
    }

    private var canSave: Bool {
        cleanName != nil && cleanPilotName != nil && !isSaving && !isPreparingCover
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Nome") {
                        TextField("Nome", text: $name, prompt: Text("Turma da serra"))
                            .multilineTextAlignment(.trailing)
                            .focused($nameFocused)
                            .submitLabel(.done)
                            .onChange(of: name) { _, typed in
                                let cut = ChallengeName.truncated(typed, maxLength: ChallengeName.challengeMaxLength)
                                if cut != typed { name = cut }
                            }
                    }
                }

                Section {
                    Picker("Duração", selection: $duration) {
                        ForEach(ChallengeDuration.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    DatePicker("Começa", selection: $startDate,
                               in: today...calendar.date(byAdding: .day, value: ChallengePeriod.maxDays, to: today)!,
                               displayedComponents: .date)
                    if duration == .until {
                        DatePicker("Termina", selection: $untilDate,
                                   in: calendar.date(byAdding: .day, value: 1, to: startDate)!
                                    ... calendar.date(byAdding: .day, value: ChallengePeriod.maxDays - 1, to: startDate)!,
                                   displayedComponents: .date)
                    }
                } header: {
                    Text("Prazo")
                } footer: {
                    Text("Termina em \(AppFormat.dayMonth(period.lastDay)) e a classificação fecha 3 dias depois, para dar tempo de registrar o último abastecimento.")
                }

                Section {
                    LabeledContent("Seu nome") {
                        TextField("Nome", text: $pilotName)
                            .multilineTextAlignment(.trailing)
                            .textContentType(.givenName)
                            .onChange(of: pilotName) { _, typed in
                                let cut = ChallengeName.truncated(typed, maxLength: ChallengeName.pilotMaxLength)
                                if cut != typed { pilotName = cut }
                            }
                    }
                } footer: {
                    Text("É o nome que a turma vê na classificação.")
                }

                Section {
                    Color.clear
                        .frame(height: 150)
                        .overlay {
                            if let cover {
                                Image(uiImage: cover.image).resizable().scaledToFill()
                            } else {
                                ChallengeCoverImage(ref: nil)
                            }
                        }
                        .overlay {
                            if isPreparingCover { ProgressView().tint(.white) }
                        }
                        .overlay(alignment: .bottomLeading) {
                            Text(name.isEmpty ? "Turma da serra" : name)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.4), radius: 6)
                                .padding()
                        }
                        .clipped()
                        .listRowInsets(EdgeInsets())
                        .accessibilityHidden(true)
                    PhotosPicker(selection: $coverItem, matching: .images) {
                        Label(cover == nil ? "Escolher foto" : "Trocar foto", systemImage: "photo")
                    }
                    .disabled(isPreparingCover)
                    if cover != nil {
                        Button("Usar a capa do Carburante", systemImage: "flag.checkered") {
                            cover = nil
                            coverItem = nil
                        }
                    }
                } header: {
                    Text("Capa")
                } footer: {
                    Text(cover == nil
                         ? "Sem foto, o desafio usa a capa do Carburante."
                         : "A turma e quem abrir o convite veem a capa.")
                }

                Section {
                    LabeledContent("Conta", value: "Km rodados")
                } footer: {
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    } else {
                        Text("Só contam abastecimentos registrados na hora, com foto do hodômetro. Todas as motos de cada piloto somam.")
                    }
                }
            }
            .navigationTitle("Novo desafio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Criar", action: save)
                            .disabled(!canSave)
                    }
                }
            }
            .onChange(of: coverItem) { _, item in
                guard let item else { return }
                isPreparingCover = true
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let jpeg = await ChallengeCover.prepare(data),
                       let image = UIImage(data: jpeg) {
                        cover = (jpeg, image)
                    }
                    isPreparingCover = false
                }
            }
            .onAppear {
                name = prefillName
                if name.isEmpty { nameFocused = true }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    private func save() {
        guard let cleanName, let cleanPilotName else { return }
        isSaving = true
        errorMessage = nil
        let period = period
        let jpeg = cover?.jpeg
        Task {
            do {
                try await onCreate(cleanName, period, cleanPilotName, jpeg)
                UserDefaults.standard.set(cleanPilotName, forKey: ChallengeName.pilotNameKey)
                Haptics.success()
                dismiss()
            } catch {
                errorMessage = ChallengeService.challengeError(error).message
                Haptics.warning()
            }
            isSaving = false
        }
    }
}
