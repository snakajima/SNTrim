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

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        drawView.delegate = self
        drawView.shapeLayer.lineWidth = 12.0
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
    
    @IBAction func slide(slider:UISlider) {
        drawView.builder.minSegment = CGFloat(slider.value)
    }
}

extension ViewController : SNDrawViewDelegate {
    func didComplete(elements:[SNPathElement]) -> Bool {
        print("complete", elements.count)

        let layerCurve = CAShapeLayer()
        
        // Extra round-trips to SVG and CGPath
        let svg = SNPath.svgFrom(elements)
        let es = SNPath.elementsFrom(svg)
        let path = SNPath.pathFrom(es)
        let es2 = SNPath.elementsFrom(path)
        
        layerCurve.path = SNPath.pathFrom(es2)
        layerCurve.lineWidth = 12
        layerCurve.fillColor = UIColor.clearColor().CGColor
        layerCurve.strokeColor = UIColor(red: 0, green: 1, blue: 0, alpha: 0.4).CGColor
        layerCurve.lineCap = "round"
        layerCurve.lineJoin = "round"
        self.view.layer.addSublayer(layerCurve)
        layers.append(layerCurve)

        return true
    }
}

