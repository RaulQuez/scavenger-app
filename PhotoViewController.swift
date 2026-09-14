//
//  PhotoViewController.swift
//  lab-task-squirrel
//
//  Created by Raul Henriquez on 9/13/26.
//

import UIKit

class PhotoViewController: UIViewController {
    @IBOutlet weak var photoView: UIImageView!
    
    var task: Task!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        photoView.image = task.image
    }
}
