//
//  ViewController.swift
//  SNTrim
//
//  Created by satoshi on 9/14/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
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
        }
    }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        self.dismissViewControllerAnimated(true) { 
            if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
                self.performSegueWithIdentifier("trim", sender: image)
            }
        }
    }
    
     @IBAction func pickImage(sender:UIButton) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = UIImagePickerControllerSourceType.PhotoLibrary
        picker.modalPresentationStyle = .Popover
        picker.popoverPresentationController?.sourceView = sender
        self.presentViewController(picker, animated: true, completion: nil)
    }
}
