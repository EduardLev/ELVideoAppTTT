//
//  PhotoLibraryCollectionViewController.swift
//  ELVideoAppTTT
//
//  Created by Eduard Lev on 3/27/18.
//  Copyright © 2018 Eduard Levshteyn. All rights reserved.
//

import UIKit
import AVFoundation

private let reuseIdentifier = "fileCell"
private let selectedCellSegue = "selectedCellSegue"

class PhotoLibraryCollectionViewController: UICollectionViewController {
    var fileURLS:[URL] = [URL]()
    var currentRow:Int = -1

    override func viewDidLoad() {
        super.viewDidLoad()
        loadFiles()
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Do any additional setup after loading the view.
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

    func loadFiles() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            self.fileURLS = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            print(fileURLS)
        } catch {
            print("Error while enumerating files \(documentsURL.path): \(error.localizedDescription)")
        }
    }


    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
        print("this is getting called")
        /*let collectionViewController = segue.destination as! ViewController
        let videoPath = self.fileURLS[currentRow]
        collectionViewController.addVideoPathToURLList(videoPath: videoPath)*/
    }

    // MARK: UICollectionViewDataSource
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView,
                                 numberOfItemsInSection section: Int) -> Int {
        return fileURLS.count
    }

    override func collectionView(_ collectionView: UICollectionView,
                                 cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier,
                                                      for: indexPath) as! FileCollectionViewCell

        cell.label.text = "Video \(indexPath.row)"
        if let thumbnailImage = self.getThumbnailImageFromVideo(url: fileURLS[indexPath.row]) {
            cell.imageView.image = thumbnailImage
        }
        return cell
    }

    // MARK: UICollectionViewDelegate

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath) as! FileCollectionViewCell
        print("the cell is getting selected")
        UIView.animate(withDuration: 0.3) {
            cell.imageView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }
        currentRow = indexPath.row
        let fileVC = self.presentingViewController as! ViewController
        let videoPath = self.fileURLS[self.currentRow]
        fileVC.addVideoPathToURLList(videoPath: videoPath)
        self.dismiss(animated: true)
    }

    override func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath) as! FileCollectionViewCell
        UIView.animate(withDuration: 0.3) {
            cell.imageView.transform = CGAffineTransform.identity
        }
    }

    /*
    // Uncomment this method to specify if the specified item should be highlighted during tracking
    override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment this method to specify if the specified item should be selected
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
    override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
    
    }
    */

}
