//
//  AskAISheet.swift
//  PeeLog
//
//  Created by Arrinal S on 30/12/25.
//

import SwiftUI

struct AskAISheet: View {
    let canAskAI: Bool
    let onSubmit: (String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var question: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                header

                questionEditor

                exampleQuestions

                Spacer()

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                submitButton
            }
            .padding(.horizontal)
            .padding(.bottom)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundColor(.purple)

            Text("Ask AI")
                .font(.title2)
                .fontWeight(.bold)

            Text("Ask one question per day about your hydration patterns.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    private var questionEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Question")
                .font(.subheadline)
                .fontWeight(.medium)

            TextEditor(text: $question)
                .frame(height: 110)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.25), lineWidth: 1)
                )

            Text("\(question.count)/500")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var exampleQuestions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Examples")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(Self.examples, id: \.self) { example in
                Button {
                    question = example
                } label: {
                    Text(example)
                        .font(.caption)
                        .foregroundColor(.purple)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack(spacing: 10) {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                    Text("Ask AI")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSubmitEnabled ? Color.purple : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!isSubmitEnabled)
    }

    private var isSubmitEnabled: Bool {
        canAskAI && !isSubmitting && !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && question.count <= 500
    }

    private func submit() async {
        guard isSubmitEnabled else { return }
        isSubmitting = true
        errorMessage = nil

        do {
            try await onSubmit(question)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }

    private static let examples: [String] = [
        "How can I improve my hydration based on my recent logs?",
        "Is my daily frequency generally healthy?",
        "What does it mean if my urine quality is often dark?"
    ]
}


