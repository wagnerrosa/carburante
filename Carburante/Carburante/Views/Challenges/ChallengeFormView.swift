//
//  ChallengeFormView.swift
//  Carburante
//
//  Novo desafio: nome, prazo em 1 toque (1 semana | 1 mês | Até…), capa.
//  Métrica fixa = km rodados (PLAN/desafios.md §Telas).
//

import SwiftUI
import PhotosUI

struct ChallengeFormView: View {
    var prefillName = ""

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var duration: Duration = .month
    @State private var startDate = Calendar.current.startOfDay(for: Date())
    @State private var untilDate = Calendar.current.date(byAdding: .day, value: 14, to: Date())!
    @State private var coverItem: PhotosPickerItem?
    @State private var coverImage: UIImage?
    @FocusState private var nameFocused: Bool

    enum Duration: Hashable, CaseIterable, Identifiable {
        case week, month, until
        var id: Self { self }
        var label: String {
            switch self {
            case .week: "1 semana"
            case .month: "1 mês"
            case .until: "Até…"
            }
        }
    }

    private var calendar: Calendar { .current }

    /// Último dia do período (conta inteiro).
    private var endDate: Date {
        switch duration {
        case .week:
            return calendar.date(byAdding: .day, value: 6, to: startDate)!
        case .month:
            let next = calendar.date(byAdding: .month, value: 1, to: startDate)!
            return calendar.date(byAdding: .day, value: -1, to: next)!
        case .until:
            return max(untilDate, startDate)
        }
    }

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Nome") {
                        TextField("Nome", text: $name, prompt: Text("Turma da serra"))
                            .multilineTextAlignment(.trailing)
                            .focused($nameFocused)
                            .submitLabel(.done)
                    }
                }

                Section {
                    Picker("Duração", selection: $duration) {
                        ForEach(Duration.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    DatePicker("Começa", selection: $startDate,
                               in: calendar.startOfDay(for: Date())...,
                               displayedComponents: .date)
                    if duration == .until {
                        DatePicker("Termina", selection: $untilDate,
                                   in: calendar.date(byAdding: .day, value: 1, to: startDate)!...,
                                   displayedComponents: .date)
                    }
                } header: {
                    Text("Prazo")
                } footer: {
                    Text("Termina em \(AppFormat.dayMonth(endDate)) e a classificação fecha 3 dias depois, para dar tempo de registrar o último abastecimento.")
                }

                Section {
                    Color.clear
                        .frame(height: 150)
                        .overlay {
                            if let coverImage {
                                Image(uiImage: coverImage).resizable().scaledToFill()
                            } else {
                                ChallengeCoverImage(ref: nil)
                            }
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
                        Label(coverImage == nil ? "Escolher foto" : "Trocar foto", systemImage: "photo")
                    }
                } header: {
                    Text("Capa")
                } footer: {
                    Text("Sem foto, o desafio usa a capa do Carburante.")
                }

                Section {
                    LabeledContent("Conta", value: "Km rodados")
                } footer: {
                    Text("Só contam abastecimentos registrados na hora, com foto do hodômetro. Todas as motos de cada piloto somam.")
                }
            }
            .navigationTitle("Novo desafio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Criar") {
                        Haptics.success()
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onChange(of: coverItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        coverImage = UIImage(data: data)
                    }
                }
            }
            .onAppear {
                name = prefillName
                if name.isEmpty { nameFocused = true }
            }
        }
    }
}
