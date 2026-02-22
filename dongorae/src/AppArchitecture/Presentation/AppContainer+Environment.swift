import SwiftUI

private struct AppContainerKey: EnvironmentKey {
    static let defaultValue: AppContainer = .live(PersistenceController.shared.container)
}

extension EnvironmentValues {
    var appContainer: AppContainer {
        get { self[AppContainerKey.self] }
        set { self[AppContainerKey.self] = newValue }
    }
}

