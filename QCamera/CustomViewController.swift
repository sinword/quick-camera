//
//  CustomViewController.swift
//  Quick Camera
//
//  Created by 新翌王 on 2023/11/10.
//  Copyright © 2023 Simon Guest. All rights reserved.
//

import Foundation
import Cocoa

class CustomViewController: NSViewController {

    let textField: NSTextField = {
        let textField = NSTextField()
        textField.stringValue = "這是一段示範文字。"
        textField.isEditable = false
        textField.isBezeled = false
        textField.alignment = .center
        textField.textColor = .white
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(textField)
        setupConstraints()
    }

    private func setupConstraints() {
        textField.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        textField.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
    }
}
