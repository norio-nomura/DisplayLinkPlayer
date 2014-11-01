//
//  ViewController.swift
//  DisplayLinkPlayer
//

import UIKit
import MobileCoreServices
import AVFoundation

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    var player: AVPlayer {
        return (view as SampleBufferDisplayLayerView).player
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    // playItemEndTimeObserving
    var playItemEndTimeObserver: AnyObject! {
        didSet {
            if oldValue != nil && !oldValue.isEqual(playItemEndTimeObserver) {
                NSNotificationCenter.defaultCenter().removeObserver(oldValue)
            }
        }
    }
    var playItemDidReachEndTime = false
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        playItemEndTimeObserver = NSNotificationCenter.defaultCenter().addObserverForName(
            AVPlayerItemDidPlayToEndTimeNotification,
            object: nil,
            queue: nil) {
                note in
                if note.object as AVPlayerItem == self.player.currentItem {
                    self.playItemDidReachEndTime = true
                }
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        playItemEndTimeObserver = nil
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func loadMovieFromCameraRoll(sender: AnyObject) {
        let videoPicker = UIImagePickerController()
        videoPicker.delegate = self
        videoPicker.sourceType = .SavedPhotosAlbum
        videoPicker.mediaTypes = [kUTTypeMovie]
        videoPicker.videoQuality = .TypeHigh
        
        videoPicker.modalPresentationStyle = .Popover
        let popPC = videoPicker.popoverPresentationController
        popPC?.permittedArrowDirections = .Any
        popPC?.barButtonItem = self.navigationItem.rightBarButtonItem
        
        dispatch_async(dispatch_get_main_queue()) {
            self.presentViewController(videoPicker, animated: true, completion: nil)
        }
    }

    @IBAction func togglePlayPause(sender: UITapGestureRecognizer) {
        if player.rate == 0.0 {
            let hostTimeNow = CMClockGetTime(CMClockGetHostTimeClock())
            let hostTimeDelta = CMTimeMakeWithSeconds(0.01, hostTimeNow.timescale)
            if playItemDidReachEndTime {
                playItemDidReachEndTime = false
                player.setRate(1.0, time: kCMTimeZero, atHostTime: hostTimeNow)
                // player.play() だと再度再生できない。
            } else {
                player.setRate(1.0, time: kCMTimeInvalid, atHostTime: hostTimeNow)
                //  player.play()
            }
        } else {
            player.pause()
        }
    }
    
    // MARK: UIImagePickerControllerDelegate
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [NSObject : AnyObject]) {
        println(info)
        self.dismissViewControllerAnimated(true, completion: nil)
        
        if let url = info[UIImagePickerControllerReferenceURL] as? NSURL {
            let item = AVPlayerItem(URL: url)
            player.replaceCurrentItemWithPlayerItem(item)
        }
    }

}

extension CMTime: DebugPrintable {
    public var debugDescription: String {
        return String(CMTimeCopyDescription(nil, self))
    }
}


