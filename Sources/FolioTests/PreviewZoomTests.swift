import Foundation
import FolioCore

func runPreviewZoomTests() {
    func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-9 }

    T.test("clamp keeps zoom within bounds") {
        T.expect(near(PreviewZoom.clamp(5.0), PreviewZoom.max), "should clamp to max")
        T.expect(near(PreviewZoom.clamp(0.01), PreviewZoom.min), "should clamp to min")
        T.expect(near(PreviewZoom.clamp(1.0), 1.0), "in-range value unchanged")
    }

    T.test("zooming in increases and respects the ceiling") {
        T.expect(PreviewZoom.zoomedIn(1.0) > 1.0, "should increase")
        T.expect(near(PreviewZoom.zoomedIn(PreviewZoom.max), PreviewZoom.max), "cannot exceed max")
    }

    T.test("zooming out decreases and respects the floor") {
        T.expect(PreviewZoom.zoomedOut(1.0) < 1.0, "should decrease")
        T.expect(near(PreviewZoom.zoomedOut(PreviewZoom.min), PreviewZoom.min), "cannot go below min")
    }

    T.test("default is 100%") {
        T.expect(near(PreviewZoom.defaultValue, 1.0), "default should be 1.0")
    }
}
