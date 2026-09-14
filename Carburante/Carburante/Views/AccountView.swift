//
//  AccountView.swift
//  Carburante
//
//  Conta do usuário. No MVP a sessão é anônima (user_id por device); Sign in with
//  Apple PROMOVE essa sessão (vincula identidade, mantém o user_id) para os dados
//  cruzarem devices. Ver SyncService.linkApple.
//
//  Atrás de uma flag (`appleSignInEnabled`): o botão da Apple só funciona com a
//  capability "Sign in with Apple" habilitada (exige Apple Developer Program
//  pago). Enquanto a flag está off, a tela explica o estado anônimo sem oferecer
//  um botão que falharia no entitlement. Ligar a flag é o último passo após
//  configurar a capability + provider Apple no Supabase.
//

import SwiftUI
import AuthenticationServices
import SwiftData

struct AccountView: View {
    @Environment(\.modelContext) private var modelContext
    /// Liga o botão Apple. Ligado na Fase 10 (2026-06-30): capability "Sign In
    /// with Apple" no target + provider Apple configurado no Supabase Auth.
    @AppStorage("appleSignInEnabled") private var appleSignInEnabled = true

    private var sync: SyncService { .shared }
    /// Nonce CRU da tentativa em curso — gerado antes do request, enviado ao
    /// Supabase com o idToken. Mantido só durante o fluxo.
    @State private var currentNonce: String?
    @State private var errorMessage: String?
    @State private var isLinking = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false

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
        LabeledContent("Status", value: "Sessão anônima")

        if appleSignInEnabled {
            SignInWithAppleButton(.signIn) { request in
                let nonce = AppleSignInNonce.random()
                currentNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = AppleSignInNonce.sha256(nonce)
            } onCompletion: { result in
                handleCompletion(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 44)
            .disabled(isLinking)
        }
    }

    // MARK: - Estado logado

    @ViewBuilder
    private var signedInState: some View {
        LabeledContent("Conta Apple", value: sync.accountEmail ?? "Conectado")
        // Sem `role: .destructive`: sair volta à sessão anônima e mantém os
        // dados locais. Vermelho fica reservado a "Excluir conta" (HIG:
        // destructive = perda de dados).
        Button("Sair") {
            Task { await sync.signOut() }
        }
        // Exclusão de conta in-app: exigência da App Store (Guideline 5.1.1(v))
        // para qualquer app que ofereça criação de conta. Apaga a conta e todos
        // os dados no servidor + o espelho local; volta ao estado anônimo.
        Button("Excluir conta", role: .destructive) {
            showDeleteConfirm = true
        }
        .disabled(isDeleting)
        .confirmationDialog(
            "Excluir conta e todos os dados?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Excluir permanentemente", role: .destructive) {
                isDeleting = true
                errorMessage = nil
                Task {
                    let ok = await sync.deleteAccount(context: modelContext)
                    isDeleting = false
                    if ok {
                        Haptics.success()
                    } else {
                        errorMessage = sync.lastError ?? "Falha ao excluir a conta."
                    }
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Isso apaga sua conta, motos, abastecimentos e histórico de todos os seus dispositivos. Não pode ser desfeito.")
        }
    }

    private var footerText: String {
        if let errorMessage { return errorMessage }
        if !appleSignInEnabled {
            return "Seus dados estão salvos só neste aparelho. Entrar com a Apple (em breve) sincroniza entre seus dispositivos sem perder nada."
        }
        return sync.isAnonymous
            ? "Entre com a Apple para acessar seus dados em qualquer dispositivo. Nada é perdido — sua moto e abastecimentos atuais são mantidos."
            : "Seus dados sincronizam entre os dispositivos onde você entrar com esta conta Apple."
    }

    // MARK: - Fluxo

    private func handleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard
                let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                errorMessage = "Não foi possível ler as credenciais da Apple."
                return
            }
            isLinking = true
            errorMessage = nil
            Task {
                let ok = await sync.linkApple(idToken: idToken, nonce: nonce, context: modelContext)
                isLinking = false
                currentNonce = nil
                if ok {
                    Haptics.success()
                } else {
                    errorMessage = sync.lastError ?? "Falha ao entrar com a Apple."
                }
            }
        case .failure(let error):
            // Cancelamento do usuário não é erro a exibir.
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            errorMessage = "Erro no login Apple: \(error.localizedDescription)"
        }
    }
}
