import CoreData
import Foundation

struct AssetEditRoute: Identifiable {
    let id: NSManagedObjectID
}

enum AssetGroupingMode {
    case byAccount
    case byAsset
}

@MainActor
final class AssetsPageViewModel: ObservableObject {
    @Published var monthCursor: Date = Date()
    @Published var showingMonthPicker = false
    @Published var showingFilter = false
    @Published var showingCreate = false
    @Published var editingRoute: AssetEditRoute?
    @Published var deleteBlockedMessage: String?
    @Published var isDeleteSelectionMode = false
    @Published var selectedAssetIDs: Set<NSManagedObjectID> = []
    @Published var groupingMode: AssetGroupingMode = .byAccount

    func startCreate() {
        showingCreate = true
    }

    func startEdit(_ id: NSManagedObjectID) {
        editingRoute = AssetEditRoute(id: id)
    }

    func blockDelete(linkedLegCount: Int) {
        deleteBlockedMessage = "이 자산은 \(linkedLegCount)개의 거래 항목에서 사용 중이라 삭제할 수 없습니다."
    }

    func toggleDeleteSelectionMode() {
        isDeleteSelectionMode.toggle()
        if !isDeleteSelectionMode {
            selectedAssetIDs = []
        }
    }

    func finishDeleteSelectionMode() {
        isDeleteSelectionMode = false
        selectedAssetIDs = []
    }

    func toggleAssetSelection(_ id: NSManagedObjectID) {
        if selectedAssetIDs.contains(id) {
            selectedAssetIDs.remove(id)
        } else {
            selectedAssetIDs.insert(id)
        }
    }

    func toggleGroupingMode() {
        groupingMode = groupingMode == .byAccount ? .byAsset : .byAccount
    }
}
