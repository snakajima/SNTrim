//
//  ViewController.swift
//  SNTrim
//
//  Created by satoshi on 9/12/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet var viewMain:UIView!
    @IBOutlet var btnUndo:UIBarButtonItem!
    @IBOutlet var btnRedo:UIBarButtonItem!
    @IBOutlet var checkerView:UIImageView!
    @IBOutlet var imageView:UIImageView!
    @IBOutlet var segment:UISegmentedControl!
    
    let image = UIImage(named: "dog.jpg")!
    var layers = [CALayer]()
    var index = 0
    var xform = CGAffineTransformIdentity {
        didSet {
            shapeLayer.lineWidth = 30 / xform.a
            builder.minSegment = 8.0 / xform.a
        }
    }
    // Image Cache
    let cacheCycle = 8
    let cacheMax = 8
    var imageCache = [(Int,UIImage?)]()
    
    // Transient properties for handlePinch
    var anchor = CGPoint.zero
    var delta = CGPoint.zero

    var builder = SNPathBuilder(minSegment: 8.0)
    lazy var shapeLayer:CAShapeLayer = {
        let layer = self.createShapeLayer()
        layer.opacity = 0.5
        self.viewMain.layer.addSublayer(layer)
        return layer
    }()
    lazy var imageTransform:CGAffineTransform = {
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
        imageView.image = image
        segment.selectedSegmentIndex = 0
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
        checkerView.image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func setTransformAnimated(xform:CGAffineTransform) {
        self.xform = xform
        UIView.animateWithDuration(0.2) { 
            self.viewMain.transform = xform
        }
    }

    @IBAction func clear() {
        for layer in layers {
            layer.removeFromSuperlayer()
        }
        layers.removeAll()
        imageCache.removeAll()
        index = 0
        imageView.image = image
        setTransformAnimated(CGAffineTransformIdentity)
        updateUI()
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
            imageView.image = image
            renderLayers(i..<index)
        } else {
            imageView.image = image
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
            imageCache.append((index, imageView.image))
        }
        updateUI()
    }
    
    private func renderLayers(range:Range<Int>) {
        UIGraphicsBeginImageContext(image.size)
        let context = UIGraphicsGetCurrentContext()!
        imageView.image?.drawInRect(CGRect(origin: .zero, size: image.size))
        CGContextConcatCTM(context, imageTransform)
        CGContextSetBlendMode(context, CGBlendMode.DestinationOut)
        for i in range {
            layers[i].renderInContext(context)
        }
        imageView.image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
    }
}

//
// MARK: HandlePan
//
extension ViewController {
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
            layers.append(layer)
            redo()
        default:
            shapeLayer.path = nil
        }
    }
}

//
// MARK: Magic Eraser
//
extension ViewController: SNTrimColorPickerDelegate {
    func didColorSelected(vc:SNTrimColorPicker, color:UIColor) {
        print("didColorSelected")
    }
    
    @IBAction func segmentSelected() {
        print("segment", segment.selectedSegmentIndex)
        if segment.selectedSegmentIndex == 1 {
            self.performSegueWithIdentifier("color", sender: nil)
        }
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let vc = segue.destinationViewController as? SNTrimColorPicker {
            vc.image = image
            vc.color = UIColor.yellowColor()
            vc.delegate = self
        }
    }
}

//
// MARK: HandlePinch
//
extension ViewController {
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
                setTransformAnimated(CGAffineTransformIdentity)
            }
        default:
            self.viewMain.transform = xform
        }
    }
}

