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

        btnAction.isEnabled = false
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print("segue", segue.destination)
        if let vc = segue.destination as? SNTrimController,
           let image = sender as? UIImage {
            vc.image = image
            vc.delegate = self
        }
    }
}

extension ViewController: SNTrimControllerDelegate {
    func wasImageTrimmed(_ controller:SNTrimController, image:UIImage?) {
        print("wasImageTrimmed")
        self.dismiss(animated: true, completion: nil)
        imageView.image = image
        btnAction.isEnabled = image != nil
    }

    func helpText(_ controller:SNTrimController, context:TrimHelpContext) -> String {
        switch(context) {
        case .colorMinus:
            return "Pick a color to remove"
        case .colorPlus:
            return "Pick a color to keep"
        }
    }
    
    @IBAction func action() {
        print("action")
        guard let image = imageView.image,
              let data = UIImagePNGRepresentation(image) else {
            return
        }
        let activity = UIActivityViewController(activityItems: [data], applicationActivities: nil)
        activity.popoverPresentationController?.barButtonItem = btnAction
        self.present(activity, animated: true, completion: nil)
    }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        self.dismiss(animated: true) {
            if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
                let sx = 1024 / image.size.width
                let sy = 1024 / image.size.height
                let scale = min(sx, sy)
                let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                UIGraphicsBeginImageContext(size)
                image.draw(in: CGRect(origin: .zero, size: size))
                let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                self.performSegue(withIdentifier: "trim", sender: resizedImage)
            }
        }
    }
    
     @IBAction func pickImage(_ sender:UIBarButtonItem) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = UIImagePickerControllerSourceType.photoLibrary
        picker.modalPresentationStyle = .popover
        picker.popoverPresentationController?.barButtonItem = sender
        self.present(picker, animated: true, completion: nil)
    }
}
