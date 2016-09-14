//
//  SNTrimColorPicker.swift
//  SNTrim
//
//  Created by satoshi on 9/13/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

import UIKit

protocol SNTrimColorPickerDelegate: class {
    func didColorSelected(vc:SNTrimColorPicker, color:UIColor)
}

class SNTrimColorPicker: UIViewController {
    @IBOutlet var mainView:UIView!
    @IBOutlet var colorView:UIView!
    weak var delegate:SNTrimColorPickerDelegate!
    var image:UIImage!
    var color:UIColor!
    let imageLayer = CALayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        //mainView.image = image
        mainView.layer.addSublayer(imageLayer)
        imageLayer.contents = image.CGImage
        imageLayer.contentsGravity = kCAGravityResizeAspect
        colorView.backgroundColor = color
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
            self.delegate.didColorSelected(self, color: self.color)
        }
    }
    
    @IBAction func handleTap(recognizer:UITapGestureRecognizer) {
        //let size = image.size
        let pt = recognizer.locationInView(mainView)
        let data = NSMutableData(length: 4)!
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedLast.rawValue)
        let context = CGBitmapContextCreate(data.mutableBytes, 1, 1, 8, 4, CGColorSpaceCreateDeviceRGB(), bitmapInfo.rawValue)!
        CGContextConcatCTM(context, CGAffineTransformMakeTranslation(-pt.x, -pt.y))
        imageLayer.renderInContext(context)
        let bytes = UnsafePointer<UInt8>(data.bytes)
        color = UIColor(red: CGFloat(bytes[0]) / 255, green: CGFloat(bytes[1]) / 255, blue: CGFloat(bytes[2]) / 255, alpha: 1.0)
        colorView.backgroundColor = color
    }
}
