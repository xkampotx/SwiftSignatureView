import UIKit

public protocol SwiftSignatureViewDelegate: class {

    func didUpdate(_ signatureView: SwiftSignatureView, isSigned: Bool)
}

open class SwiftSignatureView: UIView {

    @IBInspectable open var strokeWidth: CGFloat = 2
    @IBInspectable open var dotSize: CGFloat = 4
    @IBInspectable open var strokeColor: UIColor = .black
    @IBInspectable open var strokeAlpha: CGFloat = 1 {
        didSet {
            if strokeAlpha < 0 || strokeAlpha > 1 {
                strokeAlpha = oldValue
            }
        }
    }

    fileprivate var points: [CGPoint] = [] {
        didSet {
            let newValue = !points.isEmpty
            if newValue != isSigned {
                isSigned = newValue
            }
        }
    }

    fileprivate let scale = UIScreen.main.scale

    private (set) public var isSigned = false {
        didSet {
            delegate?.didUpdate(self, isSigned: isSigned)
        }
    }

    fileprivate var previousPoint = CGPoint.zero
    fileprivate var previousEndPoint = CGPoint.zero
    fileprivate var previousWidth: CGFloat = 0

    fileprivate (set) public var signatureImage: UIImage?

    open weak var delegate: SwiftSignatureViewDelegate?

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupRecognizers()
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupRecognizers()
    }

    private func setupRecognizers() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapHandler(_:)))
        addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(panHandler(_:)))
        pan.maximumNumberOfTouches = 1
        addGestureRecognizer(pan)
    }

    override open func draw(_ rect: CGRect) {
        signatureImage?.draw(in: rect)
    }

    public func clear() {
        signatureImage = nil
        points.removeAll()
        setNeedsDisplay()
    }
}

extension SwiftSignatureView {

    private var signatureRect: CGRect {
        guard !points.isEmpty else {
            return bounds
        }

        let xs = points.map { $0.x }.sorted()
        let ys = points.map { $0.y }.sorted()

        let minX = xs.first! * scale
        let maxX = xs.last! * scale

        let minY = ys.first! * scale
        let maxY = ys.last! * scale

        let origin = CGPoint(x: minX, y: minY)
        let size = CGSize(width: maxX - minX, height: maxY - minY)

        let inset = -strokeWidth * scale
        return CGRect(origin: origin, size: size).insetBy(dx: inset, dy: inset)
    }

    public var signatureImageByBounds: UIImage? {
        guard let croppedCGImage = signatureImage?.cgImage?.cropping(to: signatureRect) else {
            return nil
        }

        return UIImage(cgImage: croppedCGImage, scale: scale, orientation: .up)
    }
}

private extension SwiftSignatureView {

    private func setStroke() {
        let signatureColor = strokeColor.withAlphaComponent(strokeAlpha)
        signatureColor.setStroke()
        signatureColor.setFill()
    }

    private func createContextAndImage() {
        let rect = bounds
        UIGraphicsBeginImageContextWithOptions(rect.size, false, scale)
        if signatureImage == nil {
            signatureImage = UIGraphicsGetImageFromCurrentImageContext()
        }
        setStroke()
        draw(rect)
    }

    private func endImageContext() {
        signatureImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        setNeedsDisplay()
    }

    @objc func tapHandler(_ tap: UITapGestureRecognizer) {
        createContextAndImage()
        let currentPoint = tap.location(in: self)
        points.append(currentPoint)

        drawDot(at: currentPoint)
        endImageContext()
    }

    @objc func panHandler(_ pan: UIPanGestureRecognizer) {
        let currentPoint = pan.location(in: self)

        defer { points.append(currentPoint) }

        switch pan.state {
        case .began:
            previousPoint = currentPoint
            previousEndPoint = previousPoint
        case .changed:
            let strokeLength = previousPoint.distance(to: currentPoint)
            guard strokeLength >= 1.0 else {
                return
            }

            createContextAndImage()

            let delta: CGFloat = 0.5
            let strokeScale: CGFloat = 50 // fudge factor based on empirical tests
            let minValue = min(strokeWidth, 1 / strokeLength * strokeScale * delta + previousWidth * (1 - delta))
            let currentWidth = max(strokeWidth, minValue)
            let midPoint = mid(between: currentPoint, and: previousPoint)

            drawQuadCurve(previousEndPoint, control: previousPoint, end: midPoint, startWidth: previousWidth, endWidth: currentWidth)

            endImageContext()
            previousPoint = currentPoint
            previousEndPoint = midPoint
            previousWidth = currentWidth
        default:
            break
        }
    }
}

private extension SwiftSignatureView {

    func drawQuadCurve(_ start: CGPoint, control: CGPoint, end: CGPoint, startWidth: CGFloat, endWidth: CGFloat) {
        guard start != control else { return }

        let path = UIBezierPath()
        let controlWidth = (startWidth + endWidth) / 2

        let startOffsets = offsetPoints(p0: start, p1: control, width: startWidth)
        let controlOffsets = offsetPoints(p0: control, p1: start, width: controlWidth)
        let endOffsets = offsetPoints(p0: end, p1: control, width: endWidth)

        path.move(to: startOffsets.p0)
        path.addQuadCurve(to: endOffsets.p1, controlPoint: controlOffsets.p1)
        path.addLine(to: endOffsets.p0)
        path.addQuadCurve(to: startOffsets.p1, controlPoint: controlOffsets.p0)
        path.addLine(to: startOffsets.p1)

        path.lineWidth = 1
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.stroke()
        path.fill()
    }

    func drawDot(at point: CGPoint) {
        let path = UIBezierPath()
        let signatureColor = strokeColor.withAlphaComponent(strokeAlpha)
        signatureColor.setStroke()

        path.lineWidth = dotSize
        path.lineCapStyle = .round
        path.move(to: point)
        path.addLine(to: point)
        path.stroke()
    }
}

private extension SwiftSignatureView {

    func mid(between p0: CGPoint, and p1: CGPoint) -> CGPoint {
        return CGPoint(x: (p0.x + p1.x) / 2, y: (p0.y + p1.y) / 2)
    }

    func offsetPoints(p0: CGPoint, p1: CGPoint, width: CGFloat) -> (p0: CGPoint, p1: CGPoint) {
        let delta = width / 2.0
        let v0 = p1.x - p0.x
        let v1 = p1.y - p0.y
        let divisor = sqrt(v0 * v0 + v1 * v1)
        let u0 = v0 / divisor
        let u1 = v1 / divisor

        // rotate vector
        let halfPi = CGFloat.pi / 2
        let ru0 = cos(halfPi) * u0 - sin(halfPi) * u1
        let ru1 = sin(halfPi) * u0 + cos(halfPi) * u1

        // scale the vector
        let du0 = delta * ru0
        let du1 = delta * ru1

        return (.init(x: p0.x + du0, y: p0.y + du1), .init(x: p0.x - du0, y: p0.y - du1))
    }
}

private extension CGPoint {

    func distance(to point: CGPoint) -> CGFloat {
        return sqrt(pow(x - point.x, 2) + pow(y - point.y, 2))
    }
}
