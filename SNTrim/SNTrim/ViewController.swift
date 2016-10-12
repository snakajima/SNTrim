//
//  ViewController.swift
//  SNTrim
//
//  Created by satoshi on 9/14/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet var imageView:UIImageView!
    @IBOutlet var btnAction:UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()

        btnAction.enabled = false
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        print("segue", segue.destinationViewController)
        if let vc = segue.destinationViewController as? SNTrimController,
           let image = sender as? UIImage {
            vc.image = image
            vc.delegate = self
        }
    }
}

extension ViewController: SNTrimControllerDelegate {
    func wasImageTrimmed(controller:SNTrimController, image:UIImage?) {
        print("wasImageTrimmed")
        self.dismissViewControllerAnimated(true, completion: nil)
        imageView.image = image
        btnAction.enabled = true
    }

    func helpText(controller:SNTrimController, context:TrimHelpContext) -> String {
        switch(context) {
        case .colorMinus:
            return "Pick a color to remove"
        case .colorPlus:
            return "Pick a color to keep"
        }
    }
    
    @IBAction func action() {
        print("action")
    }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        self.dismissViewControllerAnimated(true) { 
            if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
                let sx = 1024 / image.size.width
                let sy = 1024 / image.size.height
                let scale = min(sx, sy)
                let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                UIGraphicsBeginImageContext(size)
                image.drawInRect(CGRect(origin: .zero, size: size))
                let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                self.performSegueWithIdentifier("trim", sender: resizedImage)
            }
        }
    }
    
     @IBAction func pickImage(_ sender:UIBarButtonItem) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = UIImagePickerControllerSourceType.PhotoLibrary
        picker.modalPresentationStyle = .Popover
        picker.popoverPresentationController?.barButtonItem = sender
        self.presentViewController(picker, animated: true, completion: nil)
    }
}
