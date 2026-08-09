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
    private let store: ConversationStore

    init(store: ConversationStore) {
        self.store = store
    }

    func reload() {
        do {
            let conversations = try store.listConversations()
            sections = Self.group(conversations)
        } catch {
            sections = []
        }
    }

    func delete(_ conversation: Conversation) {
        try? store.delete(conversation)
        reload()
    }

    func clearAll() {
        try? store.clearAll()
        reload()
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
