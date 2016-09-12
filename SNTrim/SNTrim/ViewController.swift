//
//  ViewController.swift
//  SNTrim
//
//  Created by satoshi on 9/12/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var drawView:SNDrawView!
    var layers = [CALayer]()
    var xform = CGAffineTransformIdentity

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        drawView.delegate = self
        drawView.shapeLayer.lineWidth = 12.0
        drawView.builder.minSegment = 8.0
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

extension ViewController : SNDrawViewDelegate {
    func didComplete(elements:[SNPathElement]) -> Bool {
        let layerCurve = CAShapeLayer()
        layerCurve.path = SNPath.pathFrom(elements)
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
        return true
    }
}

