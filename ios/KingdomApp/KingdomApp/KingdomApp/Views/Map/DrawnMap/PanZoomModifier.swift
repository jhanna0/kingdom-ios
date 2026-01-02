import SwiftUI

/// State container for pan and zoom transforms
struct MapTransformState {
    var offset: CGSize = .zero
    var scale: CGFloat = 1.0
    
    // Persisted values from last gesture
    var lastOffset: CGSize = .zero
    var lastScale: CGFloat = 1.0
    
    // Zoom gesture state
    var isZooming: Bool = false
    var magnificationBaseline: CGFloat = 1.0
    var scaleWhenZoomStarted: CGFloat = 1.0
    var offsetWhenZoomStarted: CGSize = .zero
    
    mutating func resetZoomGestureState() {
        isZooming = false
        magnificationBaseline = 1.0
    }
    
    mutating func persistCurrentValues() {
        lastScale = scale
        lastOffset = offset
    }
}

/// Configuration for pan/zoom behavior
struct PanZoomConfig {
    var minScale: CGFloat = 0.2
    var maxScale: CGFloat = 5.0
    var zoomThreshold: CGFloat = 0.06
    
    static let `default` = PanZoomConfig()
}

/// A view modifier that adds pan and pinch-to-zoom gestures
struct PanZoomModifier: ViewModifier {
    @Binding var transform: MapTransformState
    let config: PanZoomConfig
    
    init(transform: Binding<MapTransformState>, config: PanZoomConfig = .default) {
        self._transform = transform
        self.config = config
    }
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(dragGesture)
            .simultaneousGesture(magnificationGesture)
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Don't pan while actively zooming - magnification gesture manages offset
                if !transform.isZooming {
                    transform.offset = CGSize(
                        width: transform.lastOffset.width + value.translation.width,
                        height: transform.lastOffset.height + value.translation.height
                    )
                }
            }
            .onEnded { _ in
                transform.persistCurrentValues()
                transform.resetZoomGestureState()
            }
    }
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                // Capture baseline on first event
                if transform.magnificationBaseline == 1.0 {
                    transform.magnificationBaseline = value
                }
                
                let magnificationDelta = abs(value - transform.magnificationBaseline)
                
                // Commit to zoom mode once threshold is exceeded
                if !transform.isZooming && magnificationDelta > config.zoomThreshold {
                    transform.isZooming = true
                    transform.scaleWhenZoomStarted = transform.scale
                    transform.offsetWhenZoomStarted = transform.offset
                    transform.magnificationBaseline = value
                }
                
                // Apply zoom only after committed
                if transform.isZooming {
                    let zoomFactor = value / transform.magnificationBaseline
                    let newScale = transform.scaleWhenZoomStarted * zoomFactor
                    let clampedScale = min(max(newScale, config.minScale), config.maxScale)
                    let scaleRatio = clampedScale / transform.scaleWhenZoomStarted
                    
                    transform.scale = clampedScale
                    transform.offset = CGSize(
                        width: transform.offsetWhenZoomStarted.width * scaleRatio,
                        height: transform.offsetWhenZoomStarted.height * scaleRatio
                    )
                }
            }
            .onEnded { _ in
                transform.persistCurrentValues()
                transform.resetZoomGestureState()
            }
    }
}

extension View {
    /// Adds pan and pinch-to-zoom gestures to the view
    func panZoomable(
        transform: Binding<MapTransformState>,
        config: PanZoomConfig = .default
    ) -> some View {
        modifier(PanZoomModifier(transform: transform, config: config))
    }
}

