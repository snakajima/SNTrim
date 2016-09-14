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
    
    @IBAction func pickImage() {
        self.performSegueWithIdentifier("trim", sender: UIImage(named: "dog.jpg"))
    }
}
