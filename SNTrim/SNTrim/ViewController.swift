//
//  ViewController.swift
//  SNTrim
//
//  Created by satoshi on 9/12/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    var layers = [CALayer]()
    var xform = CGAffineTransformIdentity

    var builder = SNPathBuilder(minSegment: 8.0)
    lazy var shapeLayer:CAShapeLayer = {
        let layer = ViewController.createShapeLayer()
        self.view.layer.addSublayer(layer)
        return layer
    }()
    
    static private func createShapeLayer() -> CAShapeLayer {
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
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func clear() {
        for layer in layers {
            layer.removeFromSuperlayer()
        }
        layers.removeAll()
    }
}

//
// MARK: HandlePan
//
extension ViewController {
    @IBAction func handlePan(recognizer:UIPanGestureRecognizer) {
        let pt = recognizer.locationInView(view)
        switch(recognizer.state) {
        case .Began:
            shapeLayer.path = builder.start(pt)
        case .Changed:
            if let path = builder.move(pt) {
                shapeLayer.path = path
            }
        case .Ended:
            shapeLayer.path = nil
            let layer = ViewController.createShapeLayer()
            layer.path = builder.end()
            self.view.layer.insertSublayer(layer, below: shapeLayer)
            layers.append(layer)
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
        print("handlePinch")
        switch(recognizer.state) {
        case .Began:
            break
        case .Changed:
            self.view.transform = CGAffineTransformScale(self.xform, recognizer.scale, recognizer.scale)
        case .Ended:
            self.xform = CGAffineTransformScale(self.xform, recognizer.scale, recognizer.scale)
            self.view.transform = xform
        default:
            self.view.transform = xform
        }
    }
}

