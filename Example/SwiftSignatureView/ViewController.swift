//
//  ViewController.swift
//  SwiftSignatureView
//
//  Created by Alankar Misra on 07/17/2015.
//
// SwiftSignatureView is available under the MIT license. See the LICENSE file for more info.

import UIKit
import SwiftSignatureView

class ViewController: UIViewController {

    @IBOutlet private weak var signatureView: SwiftSignatureView! {
        didSet {
            signatureView.delegate = self
        }
    }
    @IBOutlet private weak var signatureImageView: UIImageView!

    @IBAction func didTapClear() {
        signatureView.clear()
        signatureImageView.image = nil
    }

    @IBAction func showImage() {
        signatureImageView.image = signatureView.signatureImageByBounds
    }
}

extension ViewController: SwiftSignatureViewDelegate {

    func didUpdate(_ signatureView: SwiftSignatureView, isSigned: Bool) {
        print("didSign: \(isSigned)")
    }
}
