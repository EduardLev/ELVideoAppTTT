//
//  ViewController.swift
//  ELVideoAppTTT
//
//  Created by Eduard Lev on 3/26/18.
//  Copyright © 2018 Eduard Levshteyn. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit
import MobileCoreServices

class ViewController: UIViewController {
    @IBOutlet weak var collectionView: UICollectionView!

    fileprivate var imagePickerController: UIImagePickerController!
    // This property will hold the filepaths to the videos shown in the table
    fileprivate var videoFilepaths: [URL] = [URL]()
    // Holds a fileprivate global reference to the current video index
    fileprivate var currentCollectionIndex: Int = -1

    let captureSession = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer!
    var activeInput: AVCaptureDeviceInput!
    let imageOutput = AVCapturePhotoOutput()

    

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    func setupSession() {
        captureSession.sessionPreset = AVCaptureSession.Preset.high
        let camera = AVCaptureDevice.default(for: .video)

        do {
            let input = try AVCaptureDeviceInput(device: camera!)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                activeInput = input
            }
        } catch {
            print("Error setting device input: \(error)")
        }

        let settings = AVCapturePhotoSettings()
        // imageOutput.outputSettings = [AVVideoCodecKey : AVVideoCodecJPEG]

        if captureSession.canAddOutput(imageOutput) {
            captureSession.addOutput(imageOutput)
        }
    }

    // MARK: Button Actions
    @IBAction func addVideoButtonDidTouchUpInside(_ sender: UIButton) {
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            let mediaTypes = UIImagePickerController.availableMediaTypes(for: .photoLibrary)
            if (mediaTypes?.contains(kUTTypeMovie as String))! {
                imagePickerController = UIImagePickerController()
                imagePickerController.allowsEditing = false
                imagePickerController.delegate = self
                imagePickerController.mediaTypes = [kUTTypeMovie as String]
            }
        }
        self.present(imagePickerController, animated: true, completion: nil)
    }

    // changed to camera button
    @IBAction func addRemoteStreamButtonDidTouchUpInside(_ sender: UIButton) {
        if let cameraVC = storyboard?.instantiateViewController(withIdentifier: "captureViewController") {
            present(cameraVC, animated: true)
        }
        /*let alert = UIAlertController(title: "Add Remote Stream", message: "Enter URL for remote stream.", preferredStyle: .alert)

        let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: nil)
        let doneAction = UIAlertAction(title: "Done", style: .default) { (action) in
            let textField = alert.textFields![0] as UITextField
            self.addVideoPathToURLList(videoPath: URL(string: textField.text!)!)
        }
        alert.addAction(cancelAction)
        alert.addAction(doneAction)
        alert.addTextField { (textField) in
            textField.text = "https://devimages.apple.com.edgekey.net/streaming/examples/bipbop_16x9/bibbop_16x9_variant.m3u8"
        }
        present(alert, animated: true, completion: nil)*/
    }

    @IBAction func deleteVideoButtonDidTouchUpInside(_ sender: UIButton) {
        if currentCollectionIndex != -1 {
            let alert = UIAlertController(title: "Delete Video", message: "Are you sure you want to remove this video clip from the table?", preferredStyle: .alert)
            let noAction = UIAlertAction(title: "No", style: .cancel, handler: nil)
            let yesAction = UIAlertAction(title:"Yes", style: .destructive, handler: { action in
                self.videoFilepaths.remove(at: self.currentCollectionIndex)
                self.collectionView.reloadData()
                self.currentCollectionIndex = -1
            })
            alert.addAction(noAction)
            alert.addAction(yesAction)
            self.present(alert, animated: true, completion: nil)
        }
    }

    @IBAction func playAllVideosButtonDidTouchUpInside(_ sender: UIButton) {
        if videoFilepaths.count > 0 {
            var queue = [AVPlayerItem]()
            for url in videoFilepaths {
                let videoClip = AVPlayerItem(url: url)
                queue.append(videoClip)
            }

            let queuePlayer = AVQueuePlayer(items: queue)
            queuePlayer.allowsExternalPlayback = false
            let playerViewController = AVPlayerViewController()
            playerViewController.allowsPictureInPicturePlayback = true
            playerViewController.player = queuePlayer
            present(playerViewController, animated: true, completion: nil)
            queue = []
        }
    }

    @IBAction func playVideoButtonDidTouchUpInside(_ sender: UIButton) {
        if currentCollectionIndex != -1 {
            let player = AVPlayer(url: videoFilepaths[currentCollectionIndex])
            player.allowsExternalPlayback = false
            let playerViewController = AVPlayerViewController()
            playerViewController.allowsPictureInPicturePlayback = true
            playerViewController.player = player
            self.present(playerViewController, animated: true, completion: {
            })
        }
    }

    // MARK: Helper Functions - Move to Singleton
    func addVideoPathToURLList(videoPath: URL) {
        self.videoFilepaths.append(videoPath)
        if (self.collectionView != nil) {
            self.collectionView.reloadData()
        }
    }

    func getThumbnailImageFromVideo(url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        do {
            let cgImage = try imageGenerator.copyCGImage(at: CMTimeMake(0,1), actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }
}

// MARK: Image Picker Controller Delegate
extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [String : Any]) {
        let videoPath: URL = info[UIImagePickerControllerMediaURL] as! URL
        self.addVideoPathToURLList(videoPath: videoPath)
        imagePickerController.dismiss(animated: true, completion: nil)
        imagePickerController = nil
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        imagePickerController.dismiss(animated: true, completion: nil)
        imagePickerController = nil
    }

    @IBAction func unwindToCollectionView(segue: UIStoryboardSegue) {
        // unwind to this
        print("this is happening")
        let fileVC = segue.source as! PhotoLibraryCollectionViewController
        let videoPath = fileVC.fileURLS[fileVC.currentRow]
        self.addVideoPathToURLList(videoPath: videoPath)
    }
}

extension ViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        self.currentCollectionIndex = indexPath.row
        let cell = collectionView.cellForItem(at: indexPath) as! VideoCollectionViewCell
        UIView.animate(withDuration: 0.3) {
            cell.thumbnail.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath) as! VideoCollectionViewCell
        UIView.animate(withDuration: 0.3) {
            cell.thumbnail.transform = CGAffineTransform.identity
        }
    }
}

extension ViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return videoFilepaths.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "videoCell", for: indexPath) as! VideoCollectionViewCell

        cell.nameLabel.text = "Video \(indexPath.row)"
        if let thumbnailImage = self.getThumbnailImageFromVideo(url: videoFilepaths[indexPath.row]) {
            cell.thumbnail.image = thumbnailImage
        }
        return cell
    }


}
