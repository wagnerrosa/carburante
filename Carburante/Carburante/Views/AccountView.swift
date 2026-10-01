//
//  AccountView.swift
//  Carburante
//
//  Conta do usuário. No MVP a sessão é anônima (user_id por device); Sign in with
//  Apple PROMOVE essa sessão (vincula identidade, mantém o user_id) para os dados
//  cruzarem devices — ou, se a conta Apple já existe, troca para ela levando o
//  que o aparelho tem. Ver SyncService.linkApple.
//
//  Atrás de uma flag (`appleSignInEnabled`): o botão da Apple só funciona com a
//  capability "Sign in with Apple" habilitada (exige Apple Developer Program
//  pago). Enquanto a flag está off, a tela explica o estado anônimo sem oferecer
//  um botão que falharia no entitlement. Ligar a flag é o último passo após
//  configurar a capability + provider Apple no Supabase.
//

import SwiftUI
import SwiftData

struct AccountView: View {
    @Environment(\.modelContext) private var modelContext
    /// Liga o botão Apple. Ligado na Fase 10 (2026-06-30): capability "Sign In
    /// with Apple" no target + provider Apple configurado no Supabase Auth.
    @AppStorage("appleSignInEnabled") private var appleSignInEnabled = true

    private var sync: SyncService { .shared }
    @State private var errorMessage: String?
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var showSignOutConfirm = false
    @State private var isSigningOut = false

    var body: some View {
        Section {
            if sync.isAnonymous {
                anonymousState
            } else {
                signedInState
            }
        } header: {
            Text("Conta")
        } footer: {
            Text(footerText)
        }
    }

    // MARK: - Estado anônimo

    @ViewBuilder
    private var anonymousState: some View {
        LabeledContent("Status", value: "Sem conta")

        // Some sozinho com a flag desligada (o componente decide).
        AppleSignInButton(errorMessage: $errorMessage)

        // Sem conta também há dados no servidor (sync anônimo): o usuário pode
        // apagá-los (LGPD — direito de exclusão), não só quem tem conta.
        deleteButton(title: "Apagar todos os dados")
    }

    // MARK: - Estado logado

    @ViewBuilder
    private var signedInState: some View {
        LabeledContent("Conta Apple", value: sync.accountEmail ?? "Conectado")
        // Sem `role: .destructive`: os dados ficam guardados na conta e voltam
        // ao entrar de novo. Vermelho fica reservado a "Excluir conta" (HIG:
        // destructive = perda de dados).
        Button("Sair") {
            showSignOutConfirm = true
        }
        .disabled(isSigningOut)
        .confirmationDialog(
            "Sair da conta Apple?",
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Sair") {
                isSigningOut = true
                errorMessage = nil
                Task {
                    let ok = await sync.signOut(context: modelContext)
                    isSigningOut = false
                    if !ok {
                        errorMessage = sync.lastError ?? "Falha ao sair da conta."
                    }
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Seus dados continuam guardados na sua conta e voltam quando você entrar de novo. Até lá, este iPhone fica sem dados.")
        }
        // Exclusão de conta in-app: exigência da App Store (Guideline 5.1.1(v))
        // para qualquer app que ofereça criação de conta. Apaga a conta e todos
        // os dados no servidor + o espelho local; volta ao estado anônimo.
        deleteButton(title: "Excluir conta")
    }

    // MARK: - Exclusão (conta ou só dados)

    /// Mesmo fluxo nos dois estados (`SyncService.deleteAccount` apaga o usuário
    /// da sessão, anônimo ou Apple); muda só o texto.
    private func deleteButton(title: String) -> some View {
        Button(title, role: .destructive) {
            Haptics.warning()
            showDeleteConfirm = true
        }
        .disabled(isDeleting)
        .confirmationDialog(
            sync.isAnonymous ? "Apagar todos os dados?" : "Excluir conta e todos os dados?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(sync.isAnonymous ? "Apagar permanentemente" : "Excluir permanentemente",
                   role: .destructive) {
                isDeleting = true
                errorMessage = nil
                Task {
                    let ok = await sync.deleteAccount(context: modelContext)
                    isDeleting = false
                    if ok {
                        Haptics.success()
                    } else {
                        errorMessage = sync.lastError ?? "Falha ao apagar os dados."
                    }
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(sync.isAnonymous
                 ? "Isso apaga suas motos, abastecimentos, manutenções e fotos deste iPhone e do servidor. Não pode ser desfeito."
                 : "Isso apaga sua conta, motos, abastecimentos e histórico de todos os seus dispositivos. Não pode ser desfeito.")
        }
    }

    private var footerText: String {
        if let errorMessage { return errorMessage }
        if !appleSignInEnabled {
            return "Seus dados estão salvos só neste aparelho. Entrar com a Apple (em breve) sincroniza entre seus dispositivos sem perder nada."
        }
        return sync.isAnonymous
            ? "Entre com a Apple para não perder seu histórico se trocar ou perder o iPhone. O que você já registrou continua aqui."
            : "Seus dados sincronizam entre os dispositivos onde você entrar com esta conta Apple."
    }
}
