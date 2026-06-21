import Foundation

/// Zoom level math for the preview pane, kept pure so bounds/stepping are testable.
public enum PreviewZoom {
    public static let min: Double = 0.5
    public static let max: Double = 3.0
    public static let defaultValue: Double = 1.0
    public static let step: Double = 0.1

    /// Constrain a zoom factor to the allowed range.
    public static func clamp(_ z: Double) -> Double {
        Swift.min(max, Swift.max(min, z))
    }

    public static func zoomedIn(_ z: Double) -> Double { clamp(z + step) }
    public static func zoomedOut(_ z: Double) -> Double { clamp(z - step) }
}
