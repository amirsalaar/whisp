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
        static let width: CGFloat = 280
        static let height: CGFloat = 92
        static let size = CGSize(width: width, height: height)
        static let screenInset: CGFloat = 28
    }
}
