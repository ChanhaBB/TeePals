import SwiftUI

/// Shared state that controls tab bar visibility.
/// Driven by NavigationPath depth — updates instantly at the start of
/// push/pop animations (unlike onAppear/onDisappear which fire after).
@MainActor
final class TabBarState: ObservableObject {
    @Published var isHidden = false
}
