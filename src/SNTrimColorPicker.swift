//
//  SNTrimColorPicker.swift
//  SNTrim
//
//  Created by satoshi on 9/13/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

import UIKit

protocol SNTrimColorPickerDelegate: class {
    func wasColorSelected(_ vc:SNTrimColorPicker, color:UIColor?)
}

class SNTrimColorPicker: UIViewController {
    @IBOutlet var mainView:UIView!
    @IBOutlet var colorView:UIView!
    @IBOutlet var labelHint:UILabel!
    let preView = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 80, height: 80)))
    weak var delegate:SNTrimColorPickerDelegate!
    var image:UIImage!
    var color:UIColor!
    var helpText = "Pick A Color"
    var xform = CGAffineTransform.identity
    let imageLayer = CALayer()

    // Transient properties for handlePinch
    fileprivate var anchor = CGPoint.zero
    fileprivate var delta = CGPoint.zero

    override func viewDidLoad() {
        super.viewDidLoad()
        //mainView.image = image
        mainView.layer.addSublayer(imageLayer)
        mainView.transform = xform
        imageLayer.contents = image.cgImage
        imageLayer.contentsGravity = kCAGravityResizeAspect
        colorView.backgroundColor = color
        labelHint.text = helpText
        
        self.view.addSubview(preView)
        preView.alpha = 0
        preView.layer.cornerRadius = preView.bounds.size.width / 2.0
        preView.layer.masksToBounds = true
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        imageLayer.frame = mainView.layer.bounds
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    @IBAction func done() {
        self.presentingViewController?.dismiss(animated: true) {
            self.delegate.wasColorSelected(self, color: self.color)
        }
    }

    @IBAction func cancel() {
        self.presentingViewController?.dismiss(animated: true) {
            self.delegate.wasColorSelected(self, color: nil)
        }
    }

    private func pickColor(with recognizer:UIGestureRecognizer, offset:CGSize) {
        let pt = recognizer.location(in: mainView)
        let data = NSMutableData(length: 4)!
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let context = CGContext(data: data.mutableBytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo.rawValue)!
        context.concatenate(CGAffineTransform(translationX: -pt.x, y: -pt.y))
        imageLayer.render(in: context)
        let bytes = data.bytes.assumingMemoryBound(to: UInt8.self)
        color = UIColor(red: CGFloat(bytes[0]) / 255, green: CGFloat(bytes[1]) / 255, blue: CGFloat(bytes[2]) / 255, alpha: 1.0)
        colorView.backgroundColor = color
        preView.backgroundColor = color
        preView.center = recognizer.location(in: view).translate(x: offset.width, y: offset.height)
        UIView.animate(withDuration: 0.2) { 
            self.labelHint.alpha = 0.0
        }
    }
    
    @IBAction func handlePan(_ recognizer:UIPanGestureRecognizer) {
        switch(recognizer.state) {
        case .began:
            preView.alpha = 1.0
            pickColor(with:recognizer, offset:CGSize(width: 0.0, height: -88.0))
        case .changed:
            pickColor(with:recognizer, offset:CGSize(width: 0.0, height: -88.0))
        default:
            UIView.animate(withDuration: 0.2) {
                self.preView.alpha = 0.0
            }
        }
    }
    
    @IBAction func handleTap(_ recognizer:UITapGestureRecognizer) {
        pickColor(with:recognizer, offset:.zero)
        preView.alpha = 1.0
        UIView.animate(withDuration: 0.2) {
            self.preView.alpha = 0.0
        }
    }
}

//
// MARK: HandlePinch
//
extension SNTrimColorPicker {
    private func setTransformAnimated(xform:CGAffineTransform) {
        self.xform = xform
        UIView.animate(withDuration: 0.2) { 
            self.mainView.transform = xform
        }
    }

    @IBAction func handlePinch(_ recognizer:UIPinchGestureRecognizer) {
        let ptMain = recognizer.location(in: mainView)
        let ptView = recognizer.location(in: view)

        switch(recognizer.state) {
        case .began:
            anchor = ptView
            delta = ptMain.delta(mainView.center)
        case .changed:
            if recognizer.numberOfTouches == 2 {
                var offset = ptView.delta(anchor)
                offset.x /= xform.a
                offset.y /= xform.a
                var xf = xform.translatedBy(x: offset.x + delta.x, y: offset.y + delta.y)
                xf = xf.scaledBy(x: recognizer.scale, y: recognizer.scale)
                xf = xf.translatedBy(x: -delta.x, y: -delta.y)
                self.mainView.transform = xf
            }
        case .ended:
            xform = self.mainView.transform
            if xform.a < 0.5 {
                setTransformAnimated(xform: CGAffineTransform.identity)
            }
        default:
            self.mainView.transform = xform
        }
    }
}

