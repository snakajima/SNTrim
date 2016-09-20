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

protocol SNTrimControllerDelegate : class {
    func wasImageTrimmed(controller:SNTrimController, image:UIImage?)
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
            let size = image.size
            let length = 4 * Int(size.width) * Int(size.height)
            self.pixelBuffer = SNTrimController.device?.newBufferWithLength(length, options: [.StorageModeShared])
        }
    }
    var delegate:SNTrimControllerDelegate!
    
    // Metal
    static let device = MTLCreateSystemDefaultDevice()
    static let queue = SNTrimController.device?.newCommandQueue()
    static let pipeline:MTLComputePipelineState? = {
        if let function = SNTrimController.device?.newDefaultLibrary()?.newFunctionWithName("maskImage") {
            return try! SNTrimController.device?.newComputePipelineStateWithFunction(function)
        }
        return nil
    }()
    var pixelBuffer:MTLBuffer?
    
    private let borderView:UIView = {
        let borderView = UIView()
        borderView.backgroundColor = UIColor.clearColor()
        borderView.layer.borderColor = UIColor.greenColor().CGColor
        borderView.layer.borderWidth = 4.0
        borderView.alpha = 0.0
        borderView.userInteractionEnabled = false
        return borderView
    }()
    private var trimmedImage:UIImage! {
        didSet {
            imageView.image = trimmedImage
        }
    }
    
    private var maskColor:UIColor?
    private var maskImage:UIImage?
    private var layers = [Layer]()
    private var index = 0
    private var xform = CGAffineTransformIdentity {
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
                checkerView.backgroundColor = UIColor.blackColor()
                thumbImage.backgroundColor = UIColor.blackColor()
            case .white:
                checkerView.backgroundColor = UIColor.whiteColor()
                thumbImage.backgroundColor = UIColor.whiteColor()
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
    private var anchor = CGPoint.zero
    private var delta = CGPoint.zero

    private var builder = SNPathBuilder(minSegment: 8.0)
    private lazy var shapeLayer:CAShapeLayer = {
        let layer = self.createShapeLayer()
        layer.opacity = 0.5
        self.viewMain.layer.addSublayer(layer)
        return layer
    }()
    private lazy var imageTransform:CGAffineTransform = {
        let size = self.viewMain.bounds.size
        let sx = self.image.size.width / size.width
        let sy = self.image.size.height / size.height
        if sx > sy {
            let xf = CGAffineTransformMakeScale(sx, sx)
            return CGAffineTransformTranslate(xf, 0, -(size.height - self.image.size.height / sx) / 2.0)
        } else {
            let xf = CGAffineTransformMakeScale(sy, sy)
            return CGAffineTransformTranslate(xf, -(size.width - self.image.size.width / sy) / 2.0, 0)
        }
    }()
    
    private func updateUI() {
        //print("updateUI", index, layers.count)
        btnUndo.enabled = index > 0
        btnRedo.enabled = index < layers.count
    }
    
    private func createShapeLayer() -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.contentsScale = UIScreen.mainScreen().scale
        layer.lineWidth = 30 / xform.a
        layer.fillColor = UIColor.clearColor().CGColor
        layer.strokeColor = UIColor(red: 1, green: 0, blue: 1, alpha: 1).CGColor
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
        CGContextSetFillColorWithColor(context, UIColor.lightGrayColor().CGColor)
        for x in 0...Int(size.width / 32) {
            for y in 0...Int(size.height / 32) {
                CGContextFillRect(context, CGRect(x: x * 32, y: y * 32, width: 16, height: 16))
                CGContextFillRect(context, CGRect(x: x * 32 + 16, y: y * 32 + 16, width: 16, height: 16))
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
        UIView.animateWithDuration(0.2, animations:{
            self.viewMain.transform = xform
        }, completion: completion)
    }

    @IBAction func done() {
        let frame = cropRect()
        let size = trimmedImage.size
        UIGraphicsBeginImageContext(frame.size)
        trimmedImage.drawInRect(CGRect(x: -frame.origin.x, y: -frame.origin.y, width: size.width, height: size.height))
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
        setTransformAnimated(CGAffineTransformIdentity)
        updateUI()
    }
    
    @IBAction func switchBackground() {
        //print("switchBackground")
        let rawValue = (backgroundMode.rawValue + 1) % BackgroundMode.limit.rawValue
        backgroundMode = BackgroundMode(rawValue: rawValue)!
    }
    
    @IBAction func undo() {
        if let (i,_) = imageCache.last where i == index {
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
        renderLayers(index...index)
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
    
    private func renderLayers(range:Range<Int>) {
        UIGraphicsBeginImageContext(image.size)
        let context = UIGraphicsGetCurrentContext()!
        trimmedImage.drawInRect(CGRect(origin: .zero, size: image.size))
        for i in range {
            updateMaskColor(layers[i].maskColor, fPlus: layers[i].fPlus)
            CGContextSaveGState(context)
            if let maskImage = maskImage {
                let rc = CGRect(origin: .zero, size: image.size)
                UIGraphicsBeginImageContext(image.size)
                let imageContext = UIGraphicsGetCurrentContext()!
                CGContextSaveGState(imageContext)
                CGContextConcatCTM(imageContext, CGAffineTransformMakeTranslation(0, image.size.height))
                CGContextConcatCTM(imageContext, CGAffineTransformMakeScale(1, -1))
                CGContextConcatCTM(imageContext, imageTransform)
                layers[i].layer.renderInContext(imageContext)
                CGContextRestoreGState(imageContext)

                CGContextSetBlendMode(imageContext, CGBlendMode.DestinationOut)
                CGContextDrawImage(imageContext, rc, maskImage.CGImage)

                let imageBrush = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()

                CGContextSetBlendMode(context, CGBlendMode.DestinationOut)
                CGContextDrawImage(context, rc, imageBrush.CGImage)
            } else {
                CGContextConcatCTM(context, imageTransform)
                CGContextSetBlendMode(context, CGBlendMode.DestinationOut)
                layers[i].layer.renderInContext(context)
            }
            CGContextRestoreGState(context)
        }
        trimmedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
    }
}

//
// MARK: HandlePan
//
extension SNTrimController {
    @IBAction func handlePan(recognizer:UIPanGestureRecognizer) {
        let pt = recognizer.locationInView(viewMain)
        switch(recognizer.state) {
        case .Began:
            shapeLayer.path = builder.start(pt)
        case .Changed:
            if let path = builder.move(pt) {
                shapeLayer.path = path
            }
        case .Ended:
            shapeLayer.path = nil
            let layer = createShapeLayer()
            layer.path = builder.end()
            layers.removeRange(index..<layers.count)
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
    func updateMaskColor(color:UIColor?, fPlus:Bool) {
        guard let queue = SNTrimController.queue,
              let pipeline = SNTrimController.pipeline,
              let pixelBuffer = self.pixelBuffer else {
            print("SNTrim No Metal. User CPU")
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
        
        let start = NSDate()
        let size = image.size
        var red: CGFloat = 0.0, green: CGFloat = 0.0, blue: CGFloat = 0.0, alpha: CGFloat = 0.0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let (h0, s0, v0) = colorHSV(red, g: green, b: blue)
        let (x0, y0, z0) = colorCone(h0, s: s0, v: v0)
        var bitmapInfo: UInt32 = CGBitmapInfo.ByteOrder32Big.rawValue
        bitmapInfo |= CGImageAlphaInfo.PremultipliedLast.rawValue & CGBitmapInfo.AlphaInfoMask.rawValue
        let context = CGBitmapContextCreate(pixelBuffer.contents(), Int(size.width), Int(size.height), 8, 4 * Int(size.width), CGColorSpaceCreateDeviceRGB(), bitmapInfo)!
        CGContextDrawImage(context, CGRect(origin: .zero, size:size), image.CGImage)
        
        let cmdBuffer:MTLCommandBuffer = {
            let cmdBuffer = queue.commandBuffer()
            let encoder = cmdBuffer.computeCommandEncoder(); defer { encoder.endEncoding() }
            
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
            encoder.setBuffer(pixelBuffer, offset: 0, atIndex: 0)
            encoder.setBytes(&intWidth, length: sizeofValue(intWidth), atIndex: 1)
            encoder.setBytes(&intHeight, length: sizeofValue(intHeight), atIndex: 2)
            encoder.setBytes(&pos, length: sizeofValue(pos), atIndex: 3)
            encoder.setBytes(&slack, length: sizeofValue(slack), atIndex: 4)
            encoder.setBytes(&slope, length: sizeofValue(slope), atIndex: 5)
            encoder.setBytes(&inv, length: sizeofValue(inv), atIndex: 6)
            encoder.setComputePipelineState(pipeline)

            let threadExeWidth = pipeline.threadExecutionWidth
            let threadgroupsPerGrid = MTLSize(width: (Int(size.height) + threadExeWidth - 1) / threadExeWidth, height: 1, depth: 1)
            let threadsPerThreadgroup = MTLSize(width: threadExeWidth, height: 1, depth: 1)
            encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)

            return cmdBuffer
        }()
        
        cmdBuffer.commit()
        cmdBuffer.waitUntilCompleted()
        let end = NSDate()
        print("SNTrim GPU \(size), \(end.timeIntervalSinceDate(start))")
        maskImage = UIImage(CGImage: CGBitmapContextCreateImage(context)!)
    }

    func updateMaskColorCPU(color:UIColor?, fPlus:Bool) {
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
        let (h0, s0, v0) = colorHSV(red, g: green, b: blue)
        let (x0, y0, z0) = colorCone(h0, s: s0, v: v0)
        
        let size = image.size
        let data = NSMutableData(length: 4 * Int(size.width) * Int(size.height))!
        //let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedLast.rawValue)
        var bitmapInfo: UInt32 = CGBitmapInfo.ByteOrder32Big.rawValue
        bitmapInfo |= CGImageAlphaInfo.PremultipliedLast.rawValue & CGBitmapInfo.AlphaInfoMask.rawValue
        let context = CGBitmapContextCreate(data.mutableBytes, Int(size.width), Int(size.height), 8, 4 * Int(size.width), CGColorSpaceCreateDeviceRGB(), bitmapInfo)!
        CGContextDrawImage(context, CGRect(origin: .zero, size:size), image.CGImage)
        let bytes = UnsafeMutablePointer<UInt8>(data.mutableBytes)
        let start = NSDate()
        for i in 0..<(data.length/4) {
            let (r, g, b) = (CGFloat(bytes[i*4])/255, CGFloat(bytes[i*4+1])/255, CGFloat(bytes[i*4+2])/255)
            let (h, s, v) = colorHSV(r, g: g, b: b)
            let (x, y, z) = colorCone(h, s: s, v: v)
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
        let end = NSDate()
        print("SNTrim CPU \(size), \(end.timeIntervalSinceDate(start))")
        maskImage = UIImage(CGImage: CGBitmapContextCreateImage(context)!)
    }

    func didColorSelected(vc:SNTrimColorPicker, color:UIColor) {
        updateMaskColor(color, fPlus: segment.selectedSegmentIndex==2)
    }
    
    func colorCone(h:CGFloat, s:CGFloat, v:CGFloat) -> (CGFloat, CGFloat, CGFloat) {
        let radian = h * CGFloat(M_PI * 2)
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
            self.performSegueWithIdentifier("color", sender: nil)
        }
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let vc = segue.destinationViewController as? SNTrimColorPicker {
            vc.image = image
            vc.color = UIColor.whiteColor()
            vc.xform = xform
            vc.delegate = self
        }
    }
}

//
// MARK: HandlePinch
//
extension SNTrimController {
    @IBAction func handlePinch(recognizer:UIPinchGestureRecognizer) {
        let ptMain = recognizer.locationInView(viewMain)
        let ptView = recognizer.locationInView(view)

        switch(recognizer.state) {
        case .Began:
            anchor = ptView
            delta = ptMain.delta(viewMain.center)
        case .Changed:
            if recognizer.numberOfTouches() == 2 {
                var offset = ptView.delta(anchor)
                offset.x /= xform.a
                offset.y /= xform.a
                var xf = CGAffineTransformTranslate(xform, offset.x + delta.x, offset.y + delta.y)
                xf = CGAffineTransformScale(xf, recognizer.scale, recognizer.scale)
                xf = CGAffineTransformTranslate(xf, -delta.x, -delta.y)
                self.viewMain.transform = xf
            }
        case .Ended:
            xform = self.viewMain.transform
            if xform.a < 1.0 {
                let frame = cropRect()
                self.borderView.frame = CGRectApplyAffineTransform(frame, CGAffineTransformInvert(self.imageTransform))
                self.borderView.alpha = 1.0
                UIView.animateWithDuration(0.5, animations: {
                    self.borderView.alpha = 0.0
                })
            }
        default:
            self.viewMain.transform = xform
        }
    }
    
    func cropRect() -> CGRect {
        let size = trimmedImage.size
        let (width, height) = (Int(size.width), Int(size.height))
        let data = NSMutableData(length: 4 * width * height)!
        //let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedLast.rawValue)
        var bitmapInfo: UInt32 = CGBitmapInfo.ByteOrder32Big.rawValue
        bitmapInfo |= CGImageAlphaInfo.PremultipliedLast.rawValue & CGBitmapInfo.AlphaInfoMask.rawValue
        let context = CGBitmapContextCreate(data.mutableBytes, Int(size.width), Int(size.height), 8, 4 * Int(size.width), CGColorSpaceCreateDeviceRGB(), bitmapInfo)!
        CGContextDrawImage(context, CGRect(origin: .zero, size:size), trimmedImage.CGImage)
        let words = UnsafeMutablePointer<UInt32>(data.mutableBytes)

        let start = NSDate()
        var frame = CGRect(origin: .zero, size: size)
        for y in 0..<height {
            let row = y * width
            if (0..<Int(size.width)).reduce(0, combine: { $0 | words[row + $1]}) != 0 {
                frame.origin.y = CGFloat(y)
                break
            }
        }
        for y in (Int(frame.origin.y+1)..<height).reverse() {
            let row = y * width
            if (0..<Int(size.width)).reduce(0, combine: { $0 | words[row + $1]}) != 0 {
                frame.size.height = CGFloat(y) - frame.origin.y + 1
                break
            }
        }
        for x in 0..<width {
            if (0..<height).reduce(0, combine: { $0 | words[$1 * width + x]}) != 0 {
                frame.origin.x = CGFloat(x)
                break
            }
        }
        for x in (Int(frame.origin.x)..<width).reverse() {
            if (0..<height).reduce(0, combine: { $0 | words[$1 * width + x]}) != 0 {
                frame.size.width = CGFloat(x) - frame.origin.x + 1
                break
            }
        }
        let end = NSDate()
        print("SNTrim GPU \(size), \(end.timeIntervalSinceDate(start))")

        return frame
    }
}

