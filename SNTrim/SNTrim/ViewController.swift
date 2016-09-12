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
        let shapeLayer = CAShapeLayer()
        shapeLayer.contentsScale = UIScreen.mainScreen().scale
        shapeLayer.lineWidth = 10.0
        shapeLayer.strokeColor = UIColor(red: 0, green: 0, blue: 1, alpha: 0.3).CGColor
        shapeLayer.lineCap = kCALineCapRound
        shapeLayer.lineJoin = kCALineJoinRound
        shapeLayer.fillColor = UIColor.clearColor().CGColor
        self.view.layer.addSublayer(shapeLayer)
        return shapeLayer
    }()

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
            let layerCurve = CAShapeLayer()
            layerCurve.path = builder.end()
            layerCurve.lineWidth = 12
            layerCurve.fillColor = UIColor.clearColor().CGColor
            layerCurve.strokeColor = UIColor(red: 1, green: 0, blue: 1, alpha: 1).CGColor
            layerCurve.shadowRadius = 2.0
            layerCurve.shadowColor = layerCurve.strokeColor
            layerCurve.shadowOpacity = 1.0
            layerCurve.shadowOffset = CGSize.zero
            layerCurve.lineCap = "round"
            layerCurve.lineJoin = "round"
            self.view.layer.addSublayer(layerCurve)
            layers.append(layerCurve)
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

