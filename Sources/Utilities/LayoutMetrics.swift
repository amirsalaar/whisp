import CoreGraphics
import Foundation

/// Simple layout constants (replacement for deleted Design/LayoutMetrics)
internal enum LayoutMetrics {
    enum DashboardWindow {
        static let width: CGFloat = 900
        static let height: CGFloat = 600
        static let initialSize = CGSize(width: 900, height: 600)
        static let minimumSize = CGSize(width: 700, height: 500)
        static let previewSize = CGSize(width: 900, height: 600)
    }

    enum FloatingDock {
        static let expandedSize = CGSize(width: 440, height: 108)
        static let compactSize = CGSize(width: 190, height: 52)
        static let bottomOffset: CGFloat = 14
    }
}
