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
    
    let image = UIImage(named: "dog.jpg")!
    var layers = [CALayer]()
    var index = 0
    var xform = CGAffineTransformIdentity

    var builder = SNPathBuilder(minSegment: 8.0)
    lazy var shapeLayer:CAShapeLayer = {
        let layer = self.createShapeLayer()
        layer.opacity = 0.5
        self.viewMain.layer.addSublayer(layer)
        return layer
    }()
    lazy var maskView:UIImageView = {
        let view = UIImageView(frame: self.viewMain.bounds)
        view.image = self.image
        view.contentMode = .ScaleAspectFit
        return view
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
        layer.lineWidth = 10
        layer.fillColor = UIColor.clearColor().CGColor
        layer.strokeColor = UIColor(red: 1, green: 0, blue: 1, alpha: 1).CGColor
        layer.shadowRadius = 2.0
        layer.shadowColor = layer.strokeColor
        layer.shadowOpacity = 1.0
        layer.shadowOffset = CGSize.zero
        layer.lineCap = "round"
        layer.lineJoin = "round"
        return layer
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        viewMain.addSubview(maskView)
        updateUI()
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
        index = 0
        maskView.image = image
        setTransformAnimated(CGAffineTransformIdentity)
        updateUI()
    }
    
    @IBAction func undo() {
        print("undo")
    }

    @IBAction func redo() {
        print("redo")
    }
    
    private func renderLayers(layers:[CALayer]) {
        UIGraphicsBeginImageContext(image.size)
        let context = UIGraphicsGetCurrentContext()!
        maskView.image?.drawInRect(CGRect(origin: .zero, size: image.size))
        CGContextConcatCTM(context, imageTransform)
        CGContextSetBlendMode(context, CGBlendMode.DestinationOut)
        layers.forEach { $0.renderInContext(context) }
        maskView.image = UIGraphicsGetImageFromCurrentImageContext()
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
            renderLayers([layer])
            index = layers.count
            updateUI()
        default:
            shapeLayer.path = nil
        }
    }
}

//
// MARK: HandlePinch
//
extension ViewController {
    @IBAction func handlePinch(recognizer:UIPinchGestureRecognizer) {
        switch(recognizer.state) {
        case .Began:
            break
        case .Changed:
            self.viewMain.transform = CGAffineTransformScale(self.xform, recognizer.scale, recognizer.scale)
        case .Ended:
            xform = CGAffineTransformScale(self.xform, recognizer.scale, recognizer.scale)
            self.viewMain.transform = xform
            if xform.a < 1.0 {
                setTransformAnimated(CGAffineTransformIdentity)
            }
        default:
            self.viewMain.transform = xform
        }
    }
}

