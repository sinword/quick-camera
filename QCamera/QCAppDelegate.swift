//
//  AppDelegate.swift
//  Quick Camera
//
//  Created by Simon Guest on 1/22/17.
//  Copyright © 2013-2021 Simon Guest. All rights reserved.
//

import Cocoa
import AVKit
import AVFoundation

@NSApplicationMain
class QCAppDelegate: NSObject, NSApplicationDelegate, QCUsbWatcherDelegate {

    let usb = QCUsbWatcher()
    func deviceCountChanged() {
        detectVideoDevices()
        startCaptureWithVideoDevice(defaultDevice: selectedDeviceIndex)
    }

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var selectSourceMenu: NSMenuItem!
    @IBOutlet weak var playerView: NSView!
    @IBOutlet weak var borderlessModeMenuItem: NSMenuItem!
    @IBOutlet weak var aspectRatioMenuItem: NSMenuItem!

    var isMirrored: Bool = false
    var isUpsideDown: Bool = false

    // 0 = normal, 1 = 90' top to right, 2 = 180' top to bottom, 3 = 270' top to left
    var position = 0

    var isBorderless: Bool = false
    var isAspectRatioFixed: Bool = false
    var defaultBorderStyle: NSWindow.StyleMask = NSWindow.StyleMask.closable
    var windowTitle = "Quick Camera"
    let defaultDeviceIndex: Int = 0
    var selectedDeviceIndex: Int = 0
    var deviceIndex: Int = 0

    var devices: [AVCaptureDevice]!
    var captureSession: AVCaptureSession!
    var captureLayer: AVCaptureVideoPreviewLayer!

    var input: AVCaptureDeviceInput!

    func errorMessage(message: String) {
        let popup = NSAlert()
        popup.messageText = message
        popup.runModal()
    }

    func detectVideoDevices() {
        NSLog("Detecting video devices...")
         devices = AVCaptureDevice.devices(for: AVMediaType.video)

        if devices?.count == 0 {
            let popup = NSAlert()
            popup.messageText = "Unfortunately, you don't appear to have any cameras connected. Goodbye for now!"
            popup.runModal()
            NSApp.terminate(nil)
        } else {
            NSLog("%d devices found", devices?.count ?? 0)
        }

        let deviceMenu = NSMenu()

        // Here we need to keep track of the current device (if selected) in order to keep it checked in the menu
        var currentDevice = devices[defaultDeviceIndex]
        if captureSession != nil {
            currentDevice = (captureSession.inputs[0] as! AVCaptureDeviceInput).device
        }
        selectedDeviceIndex = defaultDeviceIndex

        for device in devices {
            let deviceMenuItem =
                    NSMenuItem(title: device.localizedName, action: #selector(deviceMenuChanged), keyEquivalent: "")
            deviceMenuItem.target = self
            deviceMenuItem.representedObject = deviceIndex
            if device == currentDevice {
                deviceMenuItem.state = NSControl.StateValue.on
                selectedDeviceIndex = deviceIndex
            }
            if deviceIndex < 9 {
                deviceMenuItem.keyEquivalent = String(deviceIndex + 1)
            }
            deviceMenu.addItem(deviceMenuItem)
            deviceIndex += 1
        }
        selectSourceMenu.submenu = deviceMenu
    }

    func startCaptureWithVideoDevice(defaultDevice: Int) {
        NSLog("Starting capture with device index %d", defaultDevice)
        let device: AVCaptureDevice = devices[defaultDevice]

        if captureSession != nil {

            // if we are "restarting" a session but the device is the same exit early
            let currentDevice = (captureSession.inputs[0] as! AVCaptureDeviceInput).device
            guard currentDevice != device else { return }

            captureSession.stopRunning()
        }
        captureSession = AVCaptureSession()

        do {
            input = try AVCaptureDeviceInput(device: device)
            captureSession.addInput(input)
            captureSession.startRunning()
            captureLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            captureLayer.connection?.automaticallyAdjustsVideoMirroring = false
            captureLayer.connection?.isVideoMirrored = false

            playerView.layer = captureLayer
            playerView.layer?.backgroundColor = CGColor.black
            windowTitle = String(format: "Quick Camera: [%@]", device.localizedName)
            window.title = windowTitle
            fixAspectRatio()
            selectedDeviceIndex = defaultDevice
        } catch {
            NSLog("Error while opening device")
            errorMessage(message: "Unfortunately, there was an error when trying to access the camera. Try again or select a different one.")
        }
    }

    @IBAction func mirrorHorizontally(_ sender: NSMenuItem) {
        NSLog("Mirror image menu item selected")
        isMirrored = !isMirrored
        captureLayer.connection?.isVideoMirrored = isMirrored
    }

    func setRotation(_ position: Int) {
        switch position {
        case 1: if !isUpsideDown {
            captureLayer.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeLeft
        } else {
            captureLayer.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeRight
        }
        case 2: if !isUpsideDown {
            captureLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portraitUpsideDown
        } else {
            captureLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
        }
        case 3: if !isUpsideDown {
            captureLayer.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeRight
        } else {
            captureLayer.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeLeft
        }
        case 0: if !isUpsideDown {
            captureLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
        } else {
            captureLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portraitUpsideDown
        }
        default: break
        }
    }

    @IBAction func mirrorVertically(_ sender: NSMenuItem) {
        NSLog("Mirror image vertically menu item selected")
        isUpsideDown = !isUpsideDown
        setRotation(position)
        isMirrored = !isMirrored
        captureLayer.connection?.isVideoMirrored = isMirrored
    }

    @IBAction func rotateLeft(_ sender: NSMenuItem) {
        NSLog("Rotate Left menu item selected with position %d", position)
        position -= 1
        if position == -1 { position = 3;}
        setRotation(position)
    }

    @IBAction func rotateRight(_ sender: NSMenuItem) {
        NSLog("Rotate Right menu item selected with position %d", position)
        position += 1
        if position == 4 { position = 0;}
        setRotation(position)
    }

    private func addBorder() {
        window.styleMask = defaultBorderStyle
        window.title = windowTitle
        window.level = convertToNSWindowLevel(Int(CGWindowLevelForKey(.normalWindow)))
        window.isMovableByWindowBackground = false
        borderlessModeMenuItem.state = NSControl.StateValue.off
    }

    private func removeBorder() {
        defaultBorderStyle = window.styleMask
        window.styleMask = [NSWindow.StyleMask.borderless, NSWindow.StyleMask.resizable]
        window.level = convertToNSWindowLevel(Int(CGWindowLevelForKey(.maximumWindow)))
        window.isMovableByWindowBackground = true
        borderlessModeMenuItem.state = NSControl.StateValue.on
    }

    @IBAction func borderless(_ sender: NSMenuItem) {
        NSLog("Borderless menu item selected")
        if window.styleMask.contains(.fullScreen) {
            NSLog("Ignoring borderless command as window is full screen")
            return
        }
        isBorderless = !isBorderless
        fixBorder()
    }

    func fixBorder() {
        if isBorderless {
            removeBorder()
        } else {
            addBorder()
        }
        fixAspectRatio()
    }

    @IBAction func enterFullScreen(_ sender: NSMenuItem) {
        NSLog("Enter full screen menu item selected")
        playerView.window?.toggleFullScreen(self)
    }

    @IBAction func toggleFixAspectRatio(_ sender: NSMenuItem) {
        isAspectRatioFixed = !isAspectRatioFixed
        fixAspectRatio()
    }

    func fixAspectRatio() {
        if isAspectRatioFixed, #available(OSX 10.15, *) {
            let height = input.device.activeFormat.formatDescription.dimensions.height
            let width = input.device.activeFormat.formatDescription.dimensions.width
            let size = NSSize(width: CGFloat(width), height: CGFloat(height))
            window.contentAspectRatio = size

            let ratio = CGFloat(Float(width)/Float(height))

            var currentSize = window.contentLayoutRect.size
            currentSize.height = currentSize.width / ratio
            window.setContentSize(currentSize)
            aspectRatioMenuItem.state = NSControl.StateValue.on
        } else {
            window.contentResizeIncrements = NSSize(width: 1.0, height: 1.0)
            aspectRatioMenuItem.state = NSControl.StateValue.off
        }
    }

    @IBAction func saveImage(_ sender: NSMenuItem) {
        if window.styleMask.contains(.fullScreen) {
            NSLog("Save is not supported as window is full screen")
            return
        }

        if captureSession != nil {
            if #available(OSX 10.12, *) {
                // turn borderless on, capture image, return border to previous state
                let borderlessState = isBorderless
                if borderlessState == false {
                    NSLog("Removing border")
                    removeBorder()
                }

                /* Pause the RunLoop for 0.1 sec to let the window repaint after removing the border
                   I'm not a fan of this approach but can't find another way to listen to an event
                    for the window being updated. PRs welcome :) */
                RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))

                let cgImage = CGWindowListCreateImage(CGRect.null, .optionIncludingWindow, CGWindowID(window.windowNumber), [.boundsIgnoreFraming, .bestResolution])

                if borderlessState == false {
                    addBorder()
                }

                DispatchQueue.main.async {
                    let now = Date()
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    let date = dateFormatter.string(from: now)
                    dateFormatter.dateFormat = "h.mm.ss a"
                    let time = dateFormatter.string(from: now)

                    let panel = NSSavePanel()
                    panel.nameFieldStringValue = String(format: "Quick Camera Image %@ at %@.png", date, time)
                    panel.beginSheetModal(for: self.window) { (result) in
                        if result == NSApplication.ModalResponse.OK {
                            NSLog(panel.url!.absoluteString)
                            let destination = CGImageDestinationCreateWithURL(panel.url! as CFURL, kUTTypePNG, 1, nil)
                            if destination == nil {
                                NSLog("Could not write file - destination returned from CGImageDestinationCreateWithURL was nil")
                                self.errorMessage(message: "Unfortunately, the image could not be saved to this location.")
                            } else {
                                CGImageDestinationAddImage(destination!, cgImage!, nil)
                                CGImageDestinationFinalize(destination!)
                            }
                        }
                    }
                }
            } else {
                let popup = NSAlert()
                popup.messageText = "Unfortunately, saving images is only supported in Mac OSX 10.12 (Sierra) and higher."
                popup.runModal()
            }
        }
    }

    func setDeviceMenuSelection(selection: Int) {
        for (index, element) in selectSourceMenu.submenu!.items.enumerated() {
            element.state = NSControl.StateValue.off
            if index == selection {
                element.state = NSControl.StateValue.on
            }
        }
    }

    @objc func deviceMenuChanged(_ sender: NSMenuItem) {
        NSLog("Device Menu changed")
        if sender.state == NSControl.StateValue.on {
            // selected the active device, so nothing to do here
            return
        }
        setDeviceMenuSelection(selection: sender.representedObject as! Int)
        startCaptureWithVideoDevice(defaultDevice: sender.representedObject as! Int)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        detectVideoDevices()

        // Load device from saved settings
        NSLog("Application is starting. Loading autosaved settings.")
        let savedDevice = UserDefaults.standard.integer(forKey: "selectedDeviceIndex")
        NSLog("Loading device: %d", savedDevice)
        if savedDevice < deviceIndex {
            startCaptureWithVideoDevice(defaultDevice: savedDevice)
            setDeviceMenuSelection(selection: savedDevice)
        } else {
            startCaptureWithVideoDevice(defaultDevice: defaultDeviceIndex)
            setDeviceMenuSelection(selection: defaultDeviceIndex)
        }

        // Load rotation position
        let savedPosition = UserDefaults.standard.integer(forKey: "position")
        NSLog("Loaded position: %d", savedPosition)
        position = savedPosition
        setRotation(savedPosition)
        // Load mirroring
        let isMirrored = UserDefaults.standard.bool(forKey: "isMirrored")
        NSLog("Loaded isMirrored: %d", isMirrored)
        self.isMirrored = isMirrored
        captureLayer.connection?.isVideoMirrored = isMirrored
        // Load upside down
        let isUpsideDown = UserDefaults.standard.bool(forKey: "isUpsideDown")
        NSLog("Loaded isUpsideDown: %d", isUpsideDown)
        self.isUpsideDown = isUpsideDown
        // Load aspect ratio
        let isAspectRatioFixed = UserDefaults.standard.bool(forKey: "isAspectRatioFixed")
        NSLog("Loaded isAspectRatioFixed: %d", isAspectRatioFixed)
        self.isAspectRatioFixed = isAspectRatioFixed
        fixAspectRatio()
        // Load borderless
        let isBorderless = UserDefaults.standard.bool(forKey: "isBorderless")
        NSLog("Loading isBorderless: %d", isBorderless)
        self.isBorderless = isBorderless
        if isBorderless {
            removeBorder()
        }

        usb.delegate = self
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSLog("Application is terminating. Saving settings.")
        NSLog("Saving selected device index: %d", selectedDeviceIndex)
        UserDefaults.standard.set(selectedDeviceIndex, forKey: "selectedDeviceIndex")
        NSLog("Saving rotation position")
        UserDefaults.standard.set(position, forKey: "position")
        NSLog("Saving isMirrored")
        UserDefaults.standard.set(isMirrored, forKey: "isMirrored")
        NSLog("Saving isUpsideDown")
        UserDefaults.standard.set(isUpsideDown, forKey: "isUpsideDown")
        NSLog("Saving isAspectRatioFixed")
        UserDefaults.standard.set(isAspectRatioFixed, forKey: "isAspectRatioFixed")
        NSLog("Saving isBorderless")
        // Add border back so that we get the right coords
        if !window.styleMask.contains(.fullScreen) {
            addBorder()
        }
        UserDefaults.standard.set(isBorderless, forKey: "isBorderless")
    }
}

// Helper function inserted by Swift 4.2 migrator.
private func convertToNSWindowLevel(_ input: Int) -> NSWindow.Level {
    NSWindow.Level(rawValue: input)
}
