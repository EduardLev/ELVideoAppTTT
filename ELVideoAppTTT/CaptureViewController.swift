//
//  CaptureViewController.swift
//  ELVideoAppTTT
//
//  Created by Eduard Lev on 3/26/18.
//  Copyright © 2018 Eduard Levshteyn. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

let CaptureModePhoto = 0
let CaptureModeMovie = 1
let CaptureModeSlowMo = 2

class CaptureViewController: UIViewController {
    let captureSession = AVCaptureSession()
    let imageOutput = AVCaptureStillImageOutput()
    var previewLayer: AVCaptureVideoPreviewLayer!
    var activeInput: AVCaptureDeviceInput!
    var updateTimer: Timer!

    var focusMarker: UIImageView!
    var exposureMarker: UIImageView!
    var resetMarker: UIImageView!
    private var adjustingExposureContext: String = ""

    @IBOutlet weak var camPreview: UIView!
    @IBOutlet weak var thumbnail: UIButton!
    @IBOutlet weak var flashLabel: UILabel!
    @IBOutlet weak var modePicker: UIPickerView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var captureButton: UIButton!

    var modeData = [String]()
    var captureMode: Int = CaptureModePhoto
    let movieOutput = AVCaptureMovieFileOutput()

    // MARK: - Setup
    override func viewDidLoad() {
        super.viewDidLoad()
        modeData = ["Photo", "Video", "SlowMo"]
        if setupSession() {
            setupPreview()
            startSession()
            setupCaptureMode(mode: CaptureModePhoto)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Setup session and preview

    func setupSession() -> Bool {
        captureSession.sessionPreset = AVCaptureSession.Preset.high

        // Setup Camera
        if let camera = AVCaptureDevice.default(for: .video) {
            do {
                let input = try AVCaptureDeviceInput(device: camera)
                if captureSession.canAddInput(input) {
                    captureSession.addInput(input)
                    activeInput = input
                }
            } catch {
                print("Error setting device video input: \(error)")
                return false
            }
        }

        // Setup microphone
        if let microphone = AVCaptureDevice.default(for: .audio) {
        do {
            let micInput = try AVCaptureDeviceInput(device: microphone)
            if captureSession.canAddInput(micInput) {
                captureSession.addInput(micInput)
            }
         } catch {
             print("Error setting device audio input: \(error)")
             return false
         }
        }

        // Still image output
        imageOutput.outputSettings = [AVVideoCodecKey : AVVideoCodecType.jpeg]
        if captureSession.canAddOutput(imageOutput) {
            captureSession.addOutput(imageOutput)
        }

        // Movie output
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
        }
        return true
    }

    func setupPreview() {
        // Configure previewLayer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = camPreview.bounds
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        camPreview.layer.addSublayer(previewLayer)

        // Attach tap recognizer for focus & exposure.
        let tapForFocus = UITapGestureRecognizer(target: self, action: #selector(tapToFocus(recognizer:)))
        tapForFocus.numberOfTapsRequired = 1

        let tapForExposure = UITapGestureRecognizer(target: self, action: #selector(tapToExpose(recognizer:)))
        tapForExposure.numberOfTapsRequired = 2

        let tapForReset = UITapGestureRecognizer(target: self, action: #selector(resetFocusAndExposure))
        tapForReset.numberOfTapsRequired = 2
        tapForReset.numberOfTouchesRequired = 2

        camPreview.addGestureRecognizer(tapForFocus)
        camPreview.addGestureRecognizer(tapForExposure)
        camPreview.addGestureRecognizer(tapForReset)
        tapForFocus.require(toFail: tapForExposure)

        // Create marker views.
        focusMarker = imageViewWithImage(name: "Focus_Point")
        exposureMarker = imageViewWithImage(name: "Exposure_Point")
        resetMarker = imageViewWithImage(name: "Reset_Point")
        camPreview.addSubview(focusMarker)
        camPreview.addSubview(exposureMarker)
        camPreview.addSubview(resetMarker)
    }

    func startSession() {
        if !captureSession.isRunning {
            videoQueue().async {
                self.captureSession.startRunning()
            }
        }
    }

    func stopSession() {
        if captureSession.isRunning {
            videoQueue().async {
                self.captureSession.stopRunning()
            }
        }
    }

    func videoQueue() -> DispatchQueue {
        return DispatchQueue.global()
    }

    func startTimer() {
        if updateTimer != nil {
            updateTimer.invalidate()
        }

        updateTimer = Timer(timeInterval: 0.5, target: self, selector: #selector(updateTimeDisplay), userInfo: nil, repeats: true)

        RunLoop.main.add(updateTimer, forMode: .commonModes)
    }

    @objc func updateTimeDisplay() {
        let time = UInt(CMTimeGetSeconds(movieOutput.recordedDuration))
        timeLabel.text = formattedCurrentTime(time: time)
    }

    func stopTimer() {
        updateTimer.invalidate()
        updateTimer = nil
        timeLabel.text = formattedCurrentTime(time: UInt(0))
    }

    // MARK: - Configure
    @IBAction func switchCameras(sender: AnyObject) {
        if movieOutput.isRecording == false {
            // Make sure the device has more than 1 camera.
            if AVCaptureDevice.devices(for: AVMediaType.video).count > 1 {
                // Check which position the active camera is.
                var newPosition: AVCaptureDevice.Position!
                if activeInput.device.position == AVCaptureDevice.Position.back {
                    newPosition = AVCaptureDevice.Position.front
                } else {
                    newPosition = AVCaptureDevice.Position.back
                }

                // Get camera at new position.
                var newCamera: AVCaptureDevice!
                let devices = AVCaptureDevice.devices(for: AVMediaType.video)
                for device in devices {
                    if device.position == newPosition {
                        newCamera = device
                    }
                }

                // Create new input and update capture session.
                do {
                    let input = try AVCaptureDeviceInput(device: newCamera)
                    captureSession.beginConfiguration()
                    // Remove input for active camera.
                    captureSession.removeInput(activeInput)
                    // Add input for new camera.
                    if captureSession.canAddInput(input) {
                        captureSession.addInput(input)
                        activeInput = input
                    } else {
                        captureSession.addInput(activeInput)
                    }
                    captureSession.commitConfiguration()
                } catch {
                    print("Error switching cameras: \(error)")
                }
            }
        }
    }

    // MARK: Focus Methods
    @objc func tapToFocus(recognizer: UIGestureRecognizer) {
        if activeInput.device.isFocusPointOfInterestSupported {
            let point = recognizer.location(in: camPreview)
            let pointOfInterest = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
            showMarkerAtPoint(point: point, marker: focusMarker)
            focusAtPoint(point: pointOfInterest)
        }
    }

    func focusAtPoint(point: CGPoint) {
        let device = activeInput.device
        // Make sure the device supports focus on POI and Auto Focus.
        if device.isFocusPointOfInterestSupported &&
            device.isFocusModeSupported(AVCaptureDevice.FocusMode.autoFocus) {
            do {
                try device.lockForConfiguration()
                device.focusPointOfInterest = point
                device.focusMode = AVCaptureDevice.FocusMode.autoFocus
                device.unlockForConfiguration()
            } catch {
                print("Error focusing on POI: \(error)")
            }
        }
    }

    // MARK: Exposure Methods
    @objc func tapToExpose(recognizer: UIGestureRecognizer) {
        if activeInput.device.isExposurePointOfInterestSupported {
            let point = recognizer.location(in: camPreview)
            let pointOfInterest = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
            showMarkerAtPoint(point: point, marker: exposureMarker)
            exposeAtPoint(point: pointOfInterest)
        }
    }

    func exposeAtPoint(point: CGPoint) {
        let device = activeInput.device
        if device.isExposurePointOfInterestSupported &&
            device.isExposureModeSupported(AVCaptureDevice.ExposureMode.continuousAutoExposure) {
            do {
                try device.lockForConfiguration()
                device.exposurePointOfInterest = point
                device.exposureMode = AVCaptureDevice.ExposureMode.continuousAutoExposure

                if device.isExposureModeSupported(AVCaptureDevice.ExposureMode.locked) {
                    device.addObserver(self,
                                       forKeyPath: "adjustingExposure",
                                       options: NSKeyValueObservingOptions.new,
                                       context: &adjustingExposureContext)

                    device.unlockForConfiguration()
                }
            } catch {
                print("Error exposing on POI: \(error)")
            }
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &adjustingExposureContext {
            let device = object as! AVCaptureDevice
            if !device.isAdjustingExposure &&
                device.isExposureModeSupported(AVCaptureDevice.ExposureMode.locked) {
                (object as AnyObject).removeObserver(self,
                                                     forKeyPath: "adjustingExposure",
                                                     context: &adjustingExposureContext)

                DispatchQueue.main.async { () -> Void in
                    do {
                        try device.lockForConfiguration()
                        device.exposureMode = AVCaptureDevice.ExposureMode.locked
                        device.unlockForConfiguration()
                    } catch {
                        print("Error exposing on POI: \(error)")
                    }
                }
            }
        } else {
            super.observeValue(forKeyPath: keyPath,
                               of: object,
                               change: change,
                               context: context)
        }
    }


    // MARK: Reset Focus and Exposure
    @objc func resetFocusAndExposure() {
        let device = activeInput.device
        let focusMode = AVCaptureDevice.FocusMode.continuousAutoFocus
        let exposureMode = AVCaptureDevice.ExposureMode.continuousAutoExposure

        let canResetFocus = device.isFocusPointOfInterestSupported &&
            device.isFocusModeSupported(focusMode)
        let canResetExposure = device.isExposurePointOfInterestSupported &&
            device.isExposureModeSupported(exposureMode)

        let center = CGPoint(x: 0.5, y: 0.5)

        if canResetFocus || canResetExposure {
            let markerCenter = previewLayer.layerPointConverted(fromCaptureDevicePoint: center)
            showMarkerAtPoint(point: markerCenter, marker: resetMarker)
        }

        do {
            try device.lockForConfiguration()
            if canResetFocus {
                device.focusMode = focusMode
                device.focusPointOfInterest = center
            }
            if canResetExposure {
                device.exposureMode = exposureMode
                device.exposurePointOfInterest = center
            }

            device.unlockForConfiguration()
        } catch {
            print("Error resetting focus & exposure: \(error)")
        }
    }

    // MARK: Flash Modes (Still Photo)
    func setFlashMode() {
        let device = activeInput.device
        if device.hasFlash {
            var currentMode = currentFlashOrTorchMode().mode
            currentMode += 1
            if currentMode > 2 {
                currentMode = 0
            }

            let newMode = AVCaptureDevice.FlashMode(rawValue: currentMode)!

            if device.isFlashModeSupported(newMode) {
                do {
                    try device.lockForConfiguration()
                    device.flashMode = newMode
                    device.unlockForConfiguration()
                    flashLabel.text = currentFlashOrTorchMode().name
                } catch {
                    print("Error setting flash mode: \(error)")
                }
            }
        }
    }

    // MARK: Torch Modes (Video)
    func setTorchMode() {
        let device = activeInput.device
        if device.hasTorch {
            var currentMode = currentFlashOrTorchMode().mode
            currentMode += 1
            if currentMode > 2 {
                currentMode = 0
            }

            let newMode = AVCaptureDevice.TorchMode(rawValue: currentMode)!
            if device.isTorchModeSupported(newMode) {
                do {
                    try device.lockForConfiguration()
                    device.torchMode = newMode
                    device.unlockForConfiguration()
                    flashLabel.text = currentFlashOrTorchMode().name
                } catch {
                    print("Error setting torch mode: \(error)")
                }
            }
        }
    }


    // MARK: - Capture photo
    func capturePhoto() {
        let connection = imageOutput.connection(with: AVMediaType.video)
        if (connection?.isVideoOrientationSupported)! {
            connection?.videoOrientation = currentVideoOrientation()
        }

        imageOutput.captureStillImageAsynchronously(from: connection!) {
            (sampleBuffer: CMSampleBuffer!, error: Error!) -> Void in
            if sampleBuffer != nil {
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer)
                if let image = UIImage(data: imageData!) {
                    self.savePhotoToLibrary(image: image)
                }
            } else {
                print("Error capturing photo: \(error.localizedDescription)")
            }
        }
    }

    func getCurrentTime() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH:mm:ss"
        let dateString = dateFormatter.string(from: Date())
        return dateString
    }

    func savePhotoToDocuments(image: UIImage) -> Bool {
        do {
            let documentDirectory = getDocumentsDirectory()
            let name = getCurrentTime()
            let fileURL = documentDirectory.appendingPathComponent(name)
            if let imageData = UIImageJPEGRepresentation(image, 0.5) {
                try imageData.write(to: fileURL)
                return true
            }
        } catch {
            print("Error writing to documents: \(error.localizedDescription)")
        }
        return false
    }

    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }

    func savePhotoToLibrary(image: UIImage) {
        savePhotoToDocuments(image: image)
        let photoLibrary = PHPhotoLibrary.shared()
        photoLibrary.performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { (success: Bool, error: Error?) -> Void in
            if success {
                // Set thumbnail
                self.setPhotoThumbnail(image: image)
            } else {
                print("Error writing to photo library: \(error!.localizedDescription)")
            }
        }
    }

    func setPhotoThumbnail(image: UIImage) {
        DispatchQueue.main.async { () -> Void in
            self.thumbnail.setBackgroundImage(image, for: UIControlState.normal)
            self.thumbnail.layer.borderColor = UIColor.white.cgColor
            self.thumbnail.layer.borderWidth = 1.0
        }
    }

    // MARK: - Movie Capture
    func captureMovie() {
        if movieOutput.isRecording == false {
            let connection = movieOutput.connection(with: .video)
            if (connection?.isVideoOrientationSupported)! {
                connection?.videoOrientation = currentVideoOrientation()
            }

            if (connection?.isVideoStabilizationSupported)! {
                connection?.preferredVideoStabilizationMode = AVCaptureVideoStabilizationMode.auto
            }

            let device = activeInput.device
            if device.isSmoothAutoFocusSupported {
                do {
                    try device.lockForConfiguration()
                    device.isSmoothAutoFocusEnabled = false

                    if (captureMode == CaptureModeSlowMo) {
                        for vFormat in device.formats {
                            var ranges = vFormat.videoSupportedFrameRateRanges as [AVFrameRateRange]
                            let frameRates = ranges[0]
                            if frameRates.maxFrameRate == 240 {
                                device.activeFormat = vFormat as AVCaptureDevice.Format
                                device.activeVideoMaxFrameDuration = frameRates.minFrameDuration
                                device.activeVideoMaxFrameDuration = frameRates.maxFrameDuration
                            }
                        }
                    }

                    device.unlockForConfiguration()
                } catch {
                    print("Error setting configuration: \(error)")
                }
            }

            let outputURL = tempURL()
            movieOutput.startRecording(to: outputURL! as URL, recordingDelegate: self)
        } else {
            stopRecording()
        }
    }

    func stopRecording() {
        if movieOutput.isRecording == true {
            movieOutput.stopRecording()
        }
    }

    func saveMovieToDocuments(movieURL: NSURL) -> Bool {
        do {
            let documentDirectory = getDocumentsDirectory()
            let name = getCurrentTime()
            let fileURL = documentDirectory.appendingPathComponent("\(name).mov")
            let movieData = try? Data.init(contentsOf: movieURL as URL)
            try movieData?.write(to: fileURL)
            return true
        } catch {
            print("Error writing to documents: \(error.localizedDescription)")
    }
        return false
}

    func saveMovieToLibrary(movieURL: NSURL) {
        self.saveMovieToDocuments(movieURL: movieURL)
        let photoLibrary = PHPhotoLibrary.shared()
        photoLibrary.performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: movieURL as URL)
        }) { (success: Bool, error: Error?) -> Void in
            if success {
                // Set thumbnail
                self.setVideoThumbnailFromURL(movieURL: movieURL)
            } else {
                print("Error writing to movie library: \(error!.localizedDescription)")
            }
        }
    }

    func setVideoThumbnailFromURL(movieURL: NSURL) {
        videoQueue().async { () -> Void in
            let asset = AVAsset(url: movieURL as URL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true

            do {
                let imageRef = try imageGenerator.copyCGImage(at: kCMTimeZero,
                                                              actualTime: nil)
                let image = UIImage(cgImage: imageRef)
                self.setPhotoThumbnail(image: image)
            } catch {
                print("Error generating image: \(error)")
            }
        }
    }

    // MARK: - Helpers
    @IBAction func onFlashOrTorchButton(sender: AnyObject) {
        if captureMode == CaptureModePhoto {
            setFlashMode()
        } else {
            setTorchMode()
        }
    }

    func currentFlashOrTorchMode() -> (mode: Int, name: String) {
        var currentMode: Int = 0
        if captureMode == CaptureModePhoto {
            currentMode = activeInput.device.flashMode.rawValue
        } else {
            currentMode = activeInput.device.torchMode.rawValue
        }
        var modeName: String!

        switch currentMode {
        case 0:
            modeName = "Off"
        case 1:
            modeName = "On"
        case 2:
            modeName = "Auto"

        default:
            modeName = "Off"
        }

        if !activeInput.device.hasFlash {
            modeName = "N/A"
        }

        return (currentMode, modeName)
    }

    @IBAction func onCaptureButton(sender: AnyObject) {
        if captureMode == CaptureModePhoto {
            capturePhoto()
        } else {
            captureMovie()
        }
    }

    func setupCaptureMode(mode: Int) {
        captureMode = mode
        if mode == CaptureModePhoto {
            // Photo Mode
            timeLabel.isHidden = true
        } else  {
            // Video OR SlowMo Mode
            timeLabel.isHidden = false
        }
    }

    func imageViewWithImage(name: String) -> UIImageView {
        let view = UIImageView()
        let image = UIImage(named: name)
        view.image = image
        view.sizeToFit()
        view.isHidden = true

        return view
    }

    func showMarkerAtPoint(point: CGPoint, marker: UIImageView) {
        marker.center = point
        marker.isHidden = false

        UIView.animate(withDuration: 0.15,
                       delay: 0.0,
                       options: UIViewAnimationOptions.curveEaseInOut,
                       animations: { () -> Void in
                        marker.layer.transform = CATransform3DMakeScale(0.5, 0.5, 1.0)
        }) { (Bool) -> Void in
            let delay = 0.5
            DispatchQueue.main.async {
                marker.isHidden = true
                marker.transform = CGAffineTransform.identity
            }
        }
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "QuickLookSegue" {
            let quickLook = segue.destination as! QuickLookViewController

            if let image = thumbnail.backgroundImage(for: UIControlState.normal) {
                quickLook.photoImage = image
            } else {
                quickLook.photoImage = UIImage(named: "Penguin")
            }
        }
    }

    func currentVideoOrientation() -> AVCaptureVideoOrientation {
        var orientation: AVCaptureVideoOrientation

        switch UIDevice.current.orientation {
        case .portrait:
            orientation = AVCaptureVideoOrientation.portrait
        case .landscapeRight:
            orientation = AVCaptureVideoOrientation.landscapeLeft
        case .portraitUpsideDown:
            orientation = AVCaptureVideoOrientation.portraitUpsideDown
        default:
            orientation = AVCaptureVideoOrientation.landscapeRight
        }

        return orientation
    }

    func randomFloat(from:CGFloat, to:CGFloat) -> CGFloat {
        let rand:CGFloat = CGFloat(Float(arc4random()) / 0xFFFFFFFF)
        return (rand) * (to - from) + from
    }

    func randomInt(n: Int) -> Int {
        return Int(arc4random_uniform(UInt32(n)))
    }

    func tempURL() -> NSURL? {
        let directory = NSTemporaryDirectory() as NSString

        if directory != "" {
            let path = directory.appendingPathComponent("penCam.mov")
            return NSURL.fileURL(withPath: path) as NSURL
        }

        return nil
    }

    func formattedCurrentTime(time: UInt) -> String {
        let hours = time / 3600
        let minutes = (time / 60) % 60
        let seconds = time % 60

        return String(format: "%02i:%02i:%02i", arguments: [hours, minutes, seconds])
    }
}

extension CaptureViewController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        captureButton.setImage(UIImage(named: "Capture_Butt1"), for: .normal)
        startTimer()
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if (error != nil) {
            print("Error recording movie: \(error!.localizedDescription)")
        } else {
            // Write video to library
            saveMovieToLibrary(movieURL: outputFileURL as NSURL)
            captureButton.setImage(UIImage(named: "Capture_Butt"), for: .normal)
            stopTimer()
        }
    }
}

extension CaptureViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return modeData.count
    }

    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        let titleData = self.modeData[row]
        let myTitle = NSAttributedString(string: titleData, attributes: [NSAttributedStringKey.foregroundColor:UIColor.white])
        return myTitle
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        setupCaptureMode(mode: row)
    }
}



