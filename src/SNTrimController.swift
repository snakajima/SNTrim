//
//  SNTrimController.swift
//  SNTrim
//
//  Created by satoshi on 9/12/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

import UIKit
import MetalKit

private struct Layer {
    let layer:CALayer
    let maskColor:UIColor?
    let fPlus:Bool
}

private enum BackgroundMode: Int {
    case checker = 0
    case black = 1
    case white = 2
    case limit = 3
}

enum TrimHelpContext {
    case colorMinus
    case colorPlus
}

protocol SNTrimControllerDelegate : class {
    func wasImageTrimmed(_ controller:SNTrimController, image:UIImage?)
    func helpText(_ controller:SNTrimController, context:TrimHelpContext) -> String
}

class SNTrimController: UIViewController {
    @IBOutlet var viewMain:UIView!
    @IBOutlet var btnUndo:UIBarButtonItem!
    @IBOutlet var btnRedo:UIBarButtonItem!
    @IBOutlet var checkerView:UIImageView!
    @IBOutlet var imageView:UIImageView!
    @IBOutlet var segment:UISegmentedControl!
    @IBOutlet var thumbImage:UIImageView!
    
    var image:UIImage! {
        didSet {
            precondition(image.cgImage != nil, "SNTrimController does not support an image created from CIImage.")
            guard let device = SNTrimController.device else {
                return
            }
            let size = image.size
            let length = 4 * Int(size.width) * Int(size.height)
            self.pixelBuffer = device.makeBuffer(length: length, options: [.storageModeShared])
            self.horizontalBuffer = device.makeBuffer(length: 4 * Int(size.height), options: [.storageModeShared])
            self.verticalBuffer = device.makeBuffer(length: 4 * Int(size.width), options: [.storageModeShared])
        }
    }
    weak var delegate:SNTrimControllerDelegate!
    
    // Metal
    static let device = MTLCreateSystemDefaultDevice()
    static let queue = SNTrimController.device?.makeCommandQueue()
    static let psMask:MTLComputePipelineState? = {
        if let function = SNTrimController.device?.newDefaultLibrary()?.makeFunction(name: "SNTrimMask") {
            return try! SNTrimController.device?.makeComputePipelineState(function: function)
        }
        return nil
    }()
    static let psHorizontal:MTLComputePipelineState? = {
        if let function = SNTrimController.device?.newDefaultLibrary()?.makeFunction(name: "SNTrimHorizontal") {
            return try! SNTrimController.device?.makeComputePipelineState(function: function)
        }
        return nil
    }()
    static let psVertical:MTLComputePipelineState? = {
        if let function = SNTrimController.device?.newDefaultLibrary()?.makeFunction(name: "SNTrimVertical") {
            return try! SNTrimController.device?.makeComputePipelineState(function: function)
        }
        return nil
    }()
    var pixelBuffer:MTLBuffer?
    var horizontalBuffer:MTLBuffer?
    var verticalBuffer:MTLBuffer?
    
    fileprivate let borderView:UIView = {
        let borderView = UIView()
        borderView.backgroundColor = UIColor.clear
        borderView.layer.borderColor = UIColor.green.cgColor
        borderView.layer.borderWidth = 4.0
        borderView.alpha = 0.0
        borderView.isUserInteractionEnabled = false
        return borderView
    }()
    fileprivate var trimmedImage:UIImage! {
        didSet {
            imageView.image = trimmedImage
        }
    }
    
    fileprivate var maskColor:UIColor?
    fileprivate var maskImage:UIImage?
    fileprivate var layers = [Layer]()
    fileprivate var index = 0
    fileprivate var xform = CGAffineTransform.identity {
        didSet {
            shapeLayer.lineWidth = 30 / xform.a
            builder.minSegment = 8.0 / xform.a
        }
    }
    
    // Background
    private var backgroundMode = BackgroundMode.limit {
        didSet {
            checkerView.image = nil
            thumbImage.image = nil
            switch(backgroundMode) {
            case .checker:
                checkerView.image = checkerImage
                thumbImage.image = checkerImage
            case .black:
                checkerView.backgroundColor = .black
                thumbImage.backgroundColor = .black
            case .white:
                checkerView.backgroundColor = .white
                thumbImage.backgroundColor = .white
            default:
                break
            }
        }
    }
    private var checkerImage:UIImage?

    // Image Cache
    private let cacheCycle = 8
    private let cacheMax = 8
    private var imageCache = [(Int,UIImage?)]()
    
    // Transient properties for handlePinch
    fileprivate var anchor = CGPoint.zero
    fileprivate var delta = CGPoint.zero

    fileprivate var builder = SNPathBuilder(minSegment: 8.0)
    fileprivate lazy var shapeLayer:CAShapeLayer = {
        let layer = self.createShapeLayer()
        layer.opacity = 0.5
        self.viewMain.layer.addSublayer(layer)
        return layer
    }()
    fileprivate lazy var imageTransform:CGAffineTransform = {
        let size = self.viewMain.bounds.size
        let sx = self.image.size.width / size.width
        let sy = self.image.size.height / size.height
        if sx > sy {
            let xf = CGAffineTransform(scaleX: sx, y: sx)
            return xf.translatedBy(x: 0, y: -(size.height - self.image.size.height / sx) / 2.0)
        } else {
            let xf = CGAffineTransform(scaleX: sy, y: sy)
            return xf.translatedBy(x: -(size.width - self.image.size.width / sy) / 2.0, y: 0)
        }
    }()
    
    private func updateUI() {
        //print("updateUI", index, layers.count)
        btnUndo.isEnabled = index > 0
        btnRedo.isEnabled = index < layers.count
    }
    
    fileprivate func createShapeLayer() -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.contentsScale = UIScreen.main.scale
        layer.lineWidth = 30 / xform.a
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = UIColor(red: 1, green: 0, blue: 1, alpha: 1).cgColor
        layer.shadowRadius = 3.0
        layer.shadowColor = layer.strokeColor
        layer.shadowOpacity = 1.0
        layer.shadowOffset = CGSize.zero
        layer.lineCap = "round"
        layer.lineJoin = "round"
        return layer
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        trimmedImage = image
        segment.selectedSegmentIndex = 0
        viewMain.addSubview(borderView)
        backgroundMode = .checker
        updateUI()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let size = checkerView.bounds.size
        UIGraphicsBeginImageContext(size)
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.lightGray.cgColor)
        for x in 0...Int(size.width / 32) {
            for y in 0...Int(size.height / 32) {
                context.fill(CGRect(x: x * 32, y: y * 32, width: 16, height: 16))
                context.fill(CGRect(x: x * 32 + 16, y: y * 32 + 16, width: 16, height: 16))
            }
        }
        checkerImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        let temp = backgroundMode
        backgroundMode = .limit
        backgroundMode = temp
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func setTransformAnimated(xform:CGAffineTransform, completion:((Bool) -> Void)? = nil) {
        self.xform = xform
        UIView.animate(withDuration: 0.2, animations:{
            self.viewMain.transform = xform
        }, completion: completion)
    }

    @IBAction func done() {
        let frame = cropRect()
        let size = trimmedImage.size
        UIGraphicsBeginImageContext(frame.size)
        trimmedImage.draw(in: CGRect(x: -frame.origin.x, y: -frame.origin.y, width: size.width, height: size.height))
        let croppedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        delegate.wasImageTrimmed(self, image: croppedImage)
    }
    
    @IBAction func cancel() {
        delegate.wasImageTrimmed(self, image: nil)
    }
    
    @IBAction func clear() {
        for layer in layers {
            layer.layer.removeFromSuperlayer()
        }
        segment.selectedSegmentIndex = 0
        updateMaskColor(nil, fPlus: false)
        layers.removeAll()
        imageCache.removeAll()
        index = 0
        trimmedImage = image
        setTransformAnimated(xform: CGAffineTransform.identity)
        updateUI()
    }
    
    @IBAction func switchBackground() {
        //print("switchBackground")
        let rawValue = (backgroundMode.rawValue + 1) % BackgroundMode.limit.rawValue
        backgroundMode = BackgroundMode(rawValue: rawValue)!
    }
    
    @IBAction func undo() {
        if let (i,_) = imageCache.last, i == index {
            print("uncaching", index)
            imageCache.removeLast()
        }
        index -= 1
        if let (i, image) = imageCache.last {
            assert(i <= index)
            print("using cache", i, index)
            trimmedImage = image
            renderLayers(i..<index)
        } else {
            trimmedImage = image
            renderLayers(0..<index)
        }
        updateUI()
    }

    @IBAction func redo() {
        renderLayers(index..<index+1)
        index += 1
        if index % cacheCycle == 0 {
            if imageCache.count > cacheMax {
                print("triming")
                imageCache.removeFirst()
            }
            print("caching", index)
            imageCache.append((index, trimmedImage))
        }
        updateUI()
    }
    
    private func renderLayers(_ range:CountableRange<Int>) {
        UIGraphicsBeginImageContext(image.size)
        let context = UIGraphicsGetCurrentContext()!
        trimmedImage.draw(in: CGRect(origin: .zero, size: image.size))
        for i in range {
            updateMaskColor(layers[i].maskColor, fPlus: layers[i].fPlus)
            context.saveGState()
            if let maskImage = maskImage {
                let rc = CGRect(origin: .zero, size: image.size)
                UIGraphicsBeginImageContext(image.size)
                let imageContext = UIGraphicsGetCurrentContext()!
                imageContext.saveGState()
                imageContext.concatenate(CGAffineTransform(translationX: 0, y: image.size.height))
                imageContext.concatenate(CGAffineTransform(scaleX: 1, y: -1))
                imageContext.concatenate(imageTransform)
                layers[i].layer.render(in: imageContext)
                imageContext.restoreGState()

                imageContext.setBlendMode(CGBlendMode.destinationOut)
                imageContext.draw(maskImage.cgImage!, in: rc)

                let imageBrush = UIGraphicsGetImageFromCurrentImageContext()!
                UIGraphicsEndImageContext()

                context.setBlendMode(CGBlendMode.destinationOut)
                context.draw(imageBrush.cgImage!, in: rc)
            } else {
                context.concatenate(imageTransform)
                context.setBlendMode(CGBlendMode.destinationOut)
                layers[i].layer.render(in: context)
            }
            context.restoreGState()
        }
        trimmedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
    }
}

//
// MARK: HandlePan
//
extension SNTrimController {
    @IBAction func handlePan(_ recognizer:UIPanGestureRecognizer) {
        let pt = recognizer.location(in: viewMain)
        switch(recognizer.state) {
        case .began:
            shapeLayer.path = builder.start(pt)
        case .changed:
            if let path = builder.move(pt) {
                shapeLayer.path = path
            }
        case .ended:
            shapeLayer.path = nil
            let layer = createShapeLayer()
            layer.path = builder.end()
            layers.removeSubrange(index..<layers.count)
            layers.append(Layer(layer: layer, maskColor: maskColor, fPlus: segment.selectedSegmentIndex==2))
            redo()
        default:
            shapeLayer.path = nil
        }
    }
}

//
// MARK: Magic Eraser
//
extension SNTrimController: SNTrimColorPickerDelegate {
    func wasColorSelected(_ vc:SNTrimColorPicker, color:UIColor?) {
        if let color = color {
            updateMaskColor(color, fPlus: segment.selectedSegmentIndex==2)
        } else {
            segment.selectedSegmentIndex = 0
            updateMaskColor(nil, fPlus: false)
        }
    }
    
    func updateMaskColor(_ color:UIColor?, fPlus:Bool) {
        guard let queue = SNTrimController.queue,
              let psMask = SNTrimController.psMask,
              let pixelBuffer = self.pixelBuffer else {
            //print("SNTrim No Metal. Use CPU")
            return updateMaskColorCPU(color, fPlus: fPlus)
        }
        if maskColor == color {
            return
        }
        maskColor = color
        guard let color = color else {
            maskImage = nil
            return
        }
        
        let start = Date()
        let size = image.size
        var red: CGFloat = 0.0, green: CGFloat = 0.0, blue: CGFloat = 0.0, alpha: CGFloat = 0.0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let (h0, s0, v0) = colorHSV(r: red, g: green, b: blue)
        let (x0, y0, z0) = colorCone(h: h0, s: s0, v: v0)
        var bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Big.rawValue
        bitmapInfo |= CGImageAlphaInfo.premultipliedLast.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
        let context = CGContext(data: pixelBuffer.contents(), width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 4 * Int(size.width), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo)!
        context.draw(image.cgImage!, in: CGRect(origin: .zero, size:size))
        
        let cmdBuffer:MTLCommandBuffer = {
            let cmdBuffer = queue.makeCommandBuffer()
            let encoder = cmdBuffer.makeComputeCommandEncoder(); defer { encoder.endEncoding() }
            
            var intWidth = CUnsignedShort(size.width)
            var intHeight = CUnsignedShort(size.height)
            struct Position {
                let x:CFloat
                let y:CFloat
                let z:CFloat
            }
            var pos = Position(x: CFloat(x0), y: CFloat(y0), z: CFloat(z0))
            var slack = CFloat(0.1)
            var slope = CFloat(4.0)
            var inv = CBool(fPlus)
            encoder.setBuffer(pixelBuffer, offset: 0, at: 0)
            encoder.setBytes(&intWidth, length: MemoryLayout.size(ofValue: intWidth), at: 1)
            encoder.setBytes(&intHeight, length: MemoryLayout.size(ofValue: intHeight), at: 2)
            encoder.setBytes(&pos, length: MemoryLayout.size(ofValue: pos), at: 3)
            encoder.setBytes(&slack, length: MemoryLayout.size(ofValue: slack), at: 4)
            encoder.setBytes(&slope, length: MemoryLayout.size(ofValue: slope), at: 5)
            encoder.setBytes(&inv, length: MemoryLayout.size(ofValue: inv), at: 6)
            encoder.setComputePipelineState(psMask)

            let threadsCount = MTLSize(width: 8, height: min(8, psMask.maxTotalThreadsPerThreadgroup/8), depth: 1)
            let groupsCount = MTLSize(width: Int(size.width) / threadsCount.width, height: Int(size.height)/threadsCount.height, depth: 1)
            encoder.dispatchThreadgroups(groupsCount, threadsPerThreadgroup: threadsCount)

            return cmdBuffer
        }()
        
        cmdBuffer.commit()
        cmdBuffer.waitUntilCompleted()
        let end = Date()
        print("SNTrim GPU \(size), \(end.timeIntervalSince(start))")
        maskImage = UIImage(cgImage: context.makeImage()!)
    }

    func updateMaskColorCPU(_ color:UIColor?, fPlus:Bool) {
        if maskColor == color {
            return
        }
        maskColor = color
        guard let color = color else {
            maskImage = nil
            return
        }
        var red: CGFloat = 0.0, green: CGFloat = 0.0, blue: CGFloat = 0.0, alpha: CGFloat = 0.0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let (h0, s0, v0) = colorHSV(r: red, g: green, b: blue)
        let (x0, y0, z0) = colorCone(h: h0, s: s0, v: v0)
        
        let size = image.size
        let data = NSMutableData(length: 4 * Int(size.width) * Int(size.height))!
        //let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedLast.rawValue)
        var bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Big.rawValue
        bitmapInfo |= CGImageAlphaInfo.premultipliedLast.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
        let context = CGContext(data: data.mutableBytes, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 4 * Int(size.width), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo)!
        context.draw(image.cgImage!, in: CGRect(origin: .zero, size:size))
        let bytes = UnsafeMutablePointer(mutating: data.bytes.assumingMemoryBound(to: UInt8.self))
        let start = Date()
        //for i in 0..<(data.length/4) {
        DispatchQueue.concurrentPerform(iterations: data.length/4) { (i) in
          let (r, g, b) = (CGFloat(bytes[i*4])/255, CGFloat(bytes[i*4+1])/255, CGFloat(bytes[i*4+2])/255)
          let (h, s, v) = colorHSV(r: r, g: g, b: b)
          let (x, y, z) = colorCone(h: h, s: s, v: v)
          let (dx, dy, dz) = (x - x0, y - y0, z - z0)
          let distance = sqrt(dx * dx + dy * dy + dz * dz)
          let d:CGFloat
          d = (distance - 0.1) * 4.0
          var a = max(0, min(255, Int(d * 255)))
          if fPlus {
            a = 255 - a
          }
          bytes[i*4 + 0] = UInt8(r * CGFloat(a))
          bytes[i*4 + 1] = UInt8(g * CGFloat(a))
          bytes[i*4 + 2] = UInt8(b * CGFloat(a))
          bytes[i*4 + 3] = UInt8(a)
        }
        let end = Date()
        print("SNTrim CPU \(size), \(end.timeIntervalSince(start))")
        maskImage = UIImage(cgImage: context.makeImage()!)
    }

    func colorCone(h:CGFloat, s:CGFloat, v:CGFloat) -> (CGFloat, CGFloat, CGFloat) {
        let radian = h * .pi * 2
        let x = cos(radian) * sqrt(v) * s
        let y = sin(radian) * sqrt(v) * s
        return (x, y, v)
    }

    func colorHSV(r:CGFloat, g:CGFloat, b:CGFloat) -> (CGFloat, CGFloat, CGFloat) {
        let maxC = max(r, max(g, b))
        if maxC == 0 {
            return (0, 0, 0)
        }
        let delta = maxC - min(r, min(g, b))
        if delta == 0 {
            return (0, 0, maxC)
        }

        let delR = (((maxC - r)/6) + (delta / 2)) / delta
        let delG = (((maxC - g)/6) + (delta / 2)) / delta
        let delB = (((maxC - b)/6) + (delta / 2)) / delta
        let h:CGFloat = {
            if r == maxC {
                return delB - delG
            } else if g == maxC {
                return 1/3 + delR - delB
            } else {
                return 2/3 + delG - delR
            }
        }()
        return (h < 0 ? h + 1 : (h > 1 ? h - 1 : h), delta / maxC, maxC)
    }
    
    @IBAction func segmentSelected() {
        if segment.selectedSegmentIndex == 0 {
            updateMaskColor(nil, fPlus: false)
        } else {
            self.performSegue(withIdentifier: "color", sender: nil)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? SNTrimColorPicker {
            vc.image = image
            vc.color = .white
            vc.xform = xform
            vc.helpText = delegate.helpText(self, context: segment.selectedSegmentIndex == 1 ? .colorMinus : .colorPlus)
            vc.delegate = self
        }
    }
}

//
// MARK: HandlePinch
//
extension SNTrimController {
    @IBAction func handlePinch(_ recognizer:UIPinchGestureRecognizer) {
        let ptMain = recognizer.location(in: viewMain)
        let ptView = recognizer.location(in: view)

        switch(recognizer.state) {
        case .began:
            anchor = ptView
            delta = ptMain.delta(viewMain.center)
        case .changed:
            if recognizer.numberOfTouches == 2 {
                var offset = ptView.delta(anchor)
                offset.x /= xform.a
                offset.y /= xform.a
                var xf = xform.translatedBy(x: offset.x + delta.x, y: offset.y + delta.y)
                xf = xf.scaledBy(x: recognizer.scale, y: recognizer.scale)
                xf = xf.translatedBy(x: -delta.x, y: -delta.y)
                self.viewMain.transform = xf
            }
        case .ended:
            xform = self.viewMain.transform
            let frame = cropRect()
            self.borderView.frame = frame.applying(self.imageTransform.inverted())
            self.borderView.alpha = 1.0
            UIView.animate(withDuration: 0.5, animations: {
                self.borderView.alpha = 0.0
            })
        default:
            self.viewMain.transform = xform
        }
    }

    func cropRect() -> CGRect {
        guard let queue = SNTrimController.queue,
              let psHorizontal = SNTrimController.psHorizontal,
              let psVertical = SNTrimController.psVertical,
              let pixelBuffer = self.pixelBuffer,
              let horizontalBuffer = self.horizontalBuffer,
              let verticalBuffer = self.verticalBuffer else {
            print("SNTrim No Metal. Use CPU")
            return cropRectCPU()
        }
        let start = Date()
        let size = trimmedImage.size
        var bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Big.rawValue
        bitmapInfo |= CGImageAlphaInfo.premultipliedLast.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
        let context = CGContext(data: pixelBuffer.contents(), width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 4 * Int(size.width), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo)!
        context.clear(CGRect(origin: .zero, size:size))
        context.draw(trimmedImage.cgImage!, in: CGRect(origin: .zero, size:size))
        
        let cmdHorizontal:MTLCommandBuffer = {
            let cmdBuffer = queue.makeCommandBuffer()
            let encoder = cmdBuffer.makeComputeCommandEncoder(); defer { encoder.endEncoding() }
            
            var intWidth = CUnsignedShort(size.width)
            var intHeight = CUnsignedShort(size.height)
            encoder.setBuffer(pixelBuffer, offset: 0, at: 0)
            encoder.setBytes(&intWidth, length: MemoryLayout.size(ofValue: intWidth), at: 1)
            encoder.setBytes(&intHeight, length: MemoryLayout.size(ofValue: intHeight), at: 2)
            encoder.setBuffer(horizontalBuffer, offset: 0, at: 3)
            encoder.setComputePipelineState(psHorizontal)

            let threadExeWidth = psHorizontal.threadExecutionWidth
            let threadgroupsPerGrid = MTLSize(width: (Int(size.height) + threadExeWidth - 1) / threadExeWidth, height: 1, depth: 1)
            let threadsPerThreadgroup = MTLSize(width: threadExeWidth, height: 1, depth: 1)
            encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
            return cmdBuffer
        }()
        let cmdVertical:MTLCommandBuffer = {
            let cmdBuffer = queue.makeCommandBuffer()
            let encoder = cmdBuffer.makeComputeCommandEncoder(); defer { encoder.endEncoding() }
            
            var intWidth = CUnsignedShort(size.width)
            var intHeight = CUnsignedShort(size.height)
            encoder.setBuffer(pixelBuffer, offset: 0, at: 0)
            encoder.setBytes(&intWidth, length: MemoryLayout.size(ofValue: intWidth), at: 1)
            encoder.setBytes(&intHeight, length: MemoryLayout.size(ofValue: intHeight), at: 2)
            encoder.setBuffer(verticalBuffer, offset: 0, at: 3)
            encoder.setComputePipelineState(psVertical)

            let threadExeWidth = psVertical.threadExecutionWidth
            let threadgroupsPerGrid = MTLSize(width: (Int(size.width) + threadExeWidth - 1) / threadExeWidth, height: 1, depth: 1)
            let threadsPerThreadgroup = MTLSize(width: threadExeWidth, height: 1, depth: 1)
            encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
            return cmdBuffer
        }()
        
        cmdHorizontal.commit()
        cmdVertical.commit()
        cmdVertical.waitUntilCompleted()


        let (width, height) = (Int(size.width), Int(size.height))
        var frame = CGRect(origin: .zero, size: size)
        let hbuf = UnsafeMutablePointer(mutating: horizontalBuffer.contents().assumingMemoryBound(to: UInt32.self))
        let vbuf = UnsafeMutablePointer(mutating: verticalBuffer.contents().assumingMemoryBound(to: UInt32.self))
        for y in 0..<height {
            if hbuf[y] != 0 {
                frame.origin.y = CGFloat(y)
                break
            }
        }
        for y in (Int(frame.origin.y+1)..<height).reversed() {
            if hbuf[y] != 0 {
                frame.size.height = CGFloat(y) - frame.origin.y + 1
                break
            }
        }
        for x in 0..<width {
            if vbuf[x] != 0 {
                frame.origin.x = CGFloat(x)
                break
            }
        }
        for x in (Int(frame.origin.x)..<width).reversed() {
            if vbuf[x] != 0 {
                frame.size.width = CGFloat(x) - frame.origin.x + 1
                break
            }
        }
        let end = Date()
        print("SNTrim GPU \(size), \(end.timeIntervalSince(start))")
        return frame // cropRectCPU()
    }
    
    func cropRectCPU() -> CGRect {
        let size = trimmedImage.size
        let (width, height) = (Int(size.width), Int(size.height))
        let data = NSMutableData(length: 4 * width * height)!
        //let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedLast.rawValue)
        var bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Big.rawValue
        bitmapInfo |= CGImageAlphaInfo.premultipliedLast.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
        let context = CGContext(data: data.mutableBytes, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 4 * Int(size.width), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo)!
        context.draw(trimmedImage.cgImage!, in: CGRect(origin: .zero, size:size))
        let words = data.mutableBytes.assumingMemoryBound(to: UInt32.self)

        let start = Date()
        var frame = CGRect(origin: .zero, size: size)
        for y in 0..<height {
            let row = y * width
            if (0..<Int(size.width)).reduce(0, { $0 | words[row + $1]}) != 0 {
                frame.origin.y = CGFloat(y)
                break
            }
        }
        for y in (Int(frame.origin.y+1)..<height).reversed() {
            let row = y * width
            if (0..<Int(size.width)).reduce(0, { $0 | words[row + $1]}) != 0 {
                frame.size.height = CGFloat(y) - frame.origin.y + 1
                break
            }
        }
        for x in 0..<width {
            if (0..<height).reduce(0, { $0 | words[$1 * width + x]}) != 0 {
                frame.origin.x = CGFloat(x)
                break
            }
        }
        for x in (Int(frame.origin.x)..<width).reversed() {
            if (0..<height).reduce(0, { $0 | words[$1 * width + x]}) != 0 {
                frame.size.width = CGFloat(x) - frame.origin.x + 1
                break
            }
        }
        let end = Date()
        print("SNTrim CPU \(size), \(end.timeIntervalSince(start))")

        return frame
    }
}

