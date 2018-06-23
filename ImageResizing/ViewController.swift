//
//  ViewController.swift
//  ImageResizing
//
//  Created by roy.cao on 2018/6/23.
//  Copyright © 2018 roy.cao. All rights reserved.
//

import UIKit
import ImageIO
import CoreGraphics

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let path = Bundle.main.path(forResource: "test", ofType: "jpg")
        let image = UIImage(contentsOfFile: path!)
        
        let imageView = UIImageView.init(frame: CGRect(x: 100, y: 100, width: 200, height: 200))
//        imageView.image = image?.resizeUI(size: imageView.frame.size)
//        imageView.image = image?.resizeCG(size: imageView.frame.size)
//        imageView.image = image?.resizeIO(size: imageView.frame.size)
//        imageView.image = image?.resizeCI(size: imageView.frame.size)
        imageView.image = image?.resizeVI(size: imageView.frame.size)
        
//        let URL = Bundle.main.url(forResource: "test", withExtension: "jpg")
//        imageView.image = resizeIO(url: URL!, size: imageView.frame.size)
        
        self.view.addSubview(imageView)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}






























