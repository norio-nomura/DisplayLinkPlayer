//
//  SampleBufferDisplayLayerView.swift
//  DisplayLinkPlayer
//

import UIKit
import AVFoundation

class SampleBufferDisplayLayerView: UIView, AVPlayerItemOutputPullDelegate {
    
    override class func layerClass() -> AnyClass {
        return AVSampleBufferDisplayLayer.self
    }
    
    let player = AVPlayer()
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        player.addObserver(self, forKeyPath: "currentItem", options: .New | .Old | .Initial, context: nil)
        playerItemVideoOutput.setDelegate(self, queue: queue)
        playerItemVideoOutput.requestNotificationOfMediaDataChangeWithAdvanceInterval(advancedInterval)
        displayLink = CADisplayLink(target: self, selector: "displayLinkCallback:")
        displayLink.frameInterval = 1
        displayLink.paused = true
        displayLink.addToRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
    }
    
    // KVO
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        switch keyPath {
        case "currentItem":
            if let item = change[NSKeyValueChangeOldKey] as? AVPlayerItem {
                item.removeOutput(playerItemVideoOutput)
            }
            if let item = change[NSKeyValueChangeNewKey] as? AVPlayerItem {
                item.addOutput(playerItemVideoOutput)
                videoLayer.controlTimebase = item.timebase
            }
        default:
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }

    // MARK: AVPlayerItemOutputPullDelegate
    func outputMediaDataWillChange(sender: AVPlayerItemOutput!) {
        println("outputMediaDataWillChange")
        displayLink.paused = false
    }
    
    func outputSequenceWasFlushed(output: AVPlayerItemOutput!) {
        videoLayer.controlTimebase = player.currentItem.timebase
        videoLayer.flush()
    }
    
    // MARK: Private
    private let playerItemVideoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey:kCVPixelFormatType_32ARGB])
    private let queue = dispatch_queue_create(nil, nil)
    private let advancedInterval: NSTimeInterval = 0.1
    private let displayLink: CADisplayLink!

    private var videoLayer: AVSampleBufferDisplayLayer {
        return layer as AVSampleBufferDisplayLayer
    }
    
    private var lastTimestamp: CFTimeInterval = 0
    //MARK: CADisplayLink
    @objc func displayLinkCallback(displayLink: CADisplayLink) {
        let nextOutputHostTime = displayLink.timestamp + displayLink.duration * CFTimeInterval(displayLink.frameInterval)
        let nextOutputItemTime = playerItemVideoOutput.itemTimeForHostTime(nextOutputHostTime)
        if playerItemVideoOutput.hasNewPixelBufferForItemTime(nextOutputItemTime) {
            lastTimestamp = displayLink.timestamp
            var presentationItemTime = kCMTimeZero
            let pixelBuffer = playerItemVideoOutput.copyPixelBufferForItemTime(nextOutputItemTime, itemTimeForDisplay: &presentationItemTime)
            displayPixelBuffer(pixelBuffer, atTime: presentationItemTime)
        } else {
            if displayLink.timestamp - lastTimestamp > 0.5 {
                displayLink.paused = true
                playerItemVideoOutput.requestNotificationOfMediaDataChangeWithAdvanceInterval(advancedInterval)
            }
        }
    }

    private var videoInfo: Unmanaged<CMVideoFormatDescription>?
    private func displayPixelBuffer(pixelBuffer: CVPixelBuffer, atTime outputTime: CMTime) {
        var err: OSStatus = noErr
        
        if videoInfo == nil || 0 == CMVideoFormatDescriptionMatchesImageBuffer(videoInfo?.takeUnretainedValue(), pixelBuffer)  {
            if videoInfo != nil {
                videoInfo?.release()
                videoInfo = nil
            }
            err = CMVideoFormatDescriptionCreateForImageBuffer(nil, pixelBuffer, &videoInfo)
            if (err != noErr) {
                NSLog("Error at CMVideoFormatDescriptionCreateForImageBuffer \(err)")
            }
        }
        
        var sampleTimingInfo = CMSampleTimingInfo(duration: kCMTimeInvalid, presentationTimeStamp: outputTime, decodeTimeStamp: kCMTimeInvalid)
        var sampleBuffer: Unmanaged<CMSampleBufferRef>?
        err = CMSampleBufferCreateForImageBuffer(nil, pixelBuffer, 1, nil, nil, videoInfo?.takeUnretainedValue(), &sampleTimingInfo, &sampleBuffer)
        if (err != noErr) {
            NSLog("Error at CMSampleBufferCreateForImageBuffer \(err)")
        }
        
        if videoLayer.readyForMoreMediaData {
            videoLayer.enqueueSampleBuffer(sampleBuffer?.takeUnretainedValue())
        }
        sampleBuffer?.release()
    }
    
}
