//
//  SNTrimColorPicker.swift
//  SNTrim
//
//  Created by satoshi on 9/13/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

import UIKit

protocol SNTrimColorPickerDelegate: class {
    func wasColorSelected(vc:SNTrimColorPicker, color:UIColor?)
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
    var xform = CGAffineTransformIdentity
    let imageLayer = CALayer()

    // Transient properties for handlePinch
    private var anchor = CGPoint.zero
    private var delta = CGPoint.zero

    override func viewDidLoad() {
        super.viewDidLoad()
        //mainView.image = image
        mainView.layer.addSublayer(imageLayer)
        mainView.transform = xform
        imageLayer.contents = image.CGImage
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
        self.presentingViewController?.dismissViewControllerAnimated(true) {
            self.delegate.wasColorSelected(self, color: self.color)
        }
    }

    @IBAction func cancel() {
        self.presentingViewController?.dismissViewControllerAnimated(true) {
            self.delegate.wasColorSelected(self, color: nil)
        }
    }

    private func pickColorWith(recognizer:UIGestureRecognizer, offset:CGSize) {
        let pt = recognizer.locationInView(mainView)
        let data = NSMutableData(length: 4)!
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedLast.rawValue)
        let context = CGBitmapContextCreate(data.mutableBytes, 1, 1, 8, 4, CGColorSpaceCreateDeviceRGB(), bitmapInfo.rawValue)!
        CGContextConcatCTM(context, CGAffineTransformMakeTranslation(-pt.x, -pt.y))
        imageLayer.renderInContext(context)
        let bytes = UnsafePointer<UInt8>(data.bytes)
        color = UIColor(red: CGFloat(bytes[0]) / 255, green: CGFloat(bytes[1]) / 255, blue: CGFloat(bytes[2]) / 255, alpha: 1.0)
        colorView.backgroundColor = color
        preView.backgroundColor = color
        preView.center = recognizer.locationInView(view).translate(offset.width, y: offset.height)
        UIView.animateWithDuration(0.2) { 
            self.labelHint.alpha = 0.0
        }
    }
    
    @IBAction func handlePan(recognizer:UIPanGestureRecognizer) {
        switch(recognizer.state) {
        case .Began:
            preView.alpha = 1.0
            pickColorWith(recognizer, offset:CGSize(width: 0.0, height: -88.0))
        case .Changed:
            pickColorWith(recognizer, offset:CGSize(width: 0.0, height: -88.0))
        default:
            UIView.animateWithDuration(0.2) {
                self.preView.alpha = 0.0
            }
        }
    }
    
    @IBAction func handleTap(recognizer:UITapGestureRecognizer) {
        pickColorWith(recognizer, offset:.zero)
        preView.alpha = 1.0
        UIView.animateWithDuration(0.2) {
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
        UIView.animateWithDuration(0.2) { 
            self.mainView.transform = xform
        }
    }

    @IBAction func handlePinch(recognizer:UIPinchGestureRecognizer) {
        let ptMain = recognizer.locationInView(mainView)
        let ptView = recognizer.locationInView(view)

        switch(recognizer.state) {
        case .Began:
            anchor = ptView
            delta = ptMain.delta(mainView.center)
        case .Changed:
            if recognizer.numberOfTouches() == 2 {
                var offset = ptView.delta(anchor)
                offset.x /= xform.a
                offset.y /= xform.a
                var xf = CGAffineTransformTranslate(xform, offset.x + delta.x, offset.y + delta.y)
                xf = CGAffineTransformScale(xf, recognizer.scale, recognizer.scale)
                xf = CGAffineTransformTranslate(xf, -delta.x, -delta.y)
                self.mainView.transform = xf
            }
        case .Ended:
            xform = self.mainView.transform
            if xform.a < 0.5 {
                setTransformAnimated(CGAffineTransformIdentity)
            }
        default:
            self.mainView.transform = xform
        }
    }
}

