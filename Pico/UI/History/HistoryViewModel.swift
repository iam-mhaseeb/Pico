import Foundation
import SwiftUI

struct HistorySection: Identifiable {
    let id: String
    let title: String
    let conversations: [Conversation]
}

@MainActor
@Observable
final class HistoryViewModel {
    var sections: [HistorySection] = []
    var query = ""
    var conversationPendingDelete: Conversation?
    var conversationPendingRename: Conversation?
    var renameDraft = ""
    var loadError: String?
    private let store: ConversationStore

    init(store: ConversationStore) {
        self.store = store
    }

    func reload() {
        do {
            let conversations = try store.listConversations()
            sections = Self.group(conversations)
            loadError = nil
        } catch {
            sections = []
            loadError = "Couldn’t load history."
        }
    }

    func requestDelete(_ conversation: Conversation) {
        conversationPendingDelete = conversation
    }

    func confirmDelete() {
        guard let conversation = conversationPendingDelete else { return }
        try? store.delete(conversation)
        conversationPendingDelete = nil
        reload()
    }

    func cancelDelete() {
        conversationPendingDelete = nil
    }

    func clearAll() {
        try? store.clearAll()
        reload()
    }

    func beginRename(_ conversation: Conversation) {
        conversationPendingRename = conversation
        renameDraft = conversation.title
    }

    func confirmRename() {
        guard let conversation = conversationPendingRename else { return }
        let title = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            try? store.setTitle(title, for: conversation)
        }
        conversationPendingRename = nil
        reload()
    }

    func cancelRename() {
        conversationPendingRename = nil
    }

    var displayedSections: [HistorySection] {
        Self.filter(sections, query: query)
    }

    static func filter(_ sections: [HistorySection], query: String) -> [HistorySection] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sections }
        return sections.compactMap { section in
            let matches = section.conversations.filter {
                $0.title.localizedCaseInsensitiveContains(trimmed)
            }
            guard !matches.isEmpty else { return nil }
            return HistorySection(id: section.id, title: section.title, conversations: matches)
        }
    }

    private static func group(_ conversations: [Conversation]) -> [HistorySection] {
        let calendar = Calendar.current
        let today = conversations.filter { calendar.isDateInToday($0.updatedAt) }
        let yesterday = conversations.filter { calendar.isDateInYesterday($0.updatedAt) }
        let previous = conversations.filter {
            !calendar.isDateInToday($0.updatedAt) && !calendar.isDateInYesterday($0.updatedAt)
        }

        var result: [HistorySection] = []
        if !today.isEmpty { result.append(HistorySection(id: "today", title: "Today", conversations: today)) }
        if !yesterday.isEmpty { result.append(HistorySection(id: "yesterday", title: "Yesterday", conversations: yesterday)) }
        if !previous.isEmpty { result.append(HistorySection(id: "previous", title: "Previous", conversations: previous)) }
        return result
    }
}
