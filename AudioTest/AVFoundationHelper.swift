
import Foundation
import AVFoundation

let defaultAudioExtension = "m4a"
let defaultBackingAudioName = "BackingAudio"
let defaultRecordingAudioName = "RecordingAudio"
let defaultBouncedAudioName = "BouncedAudio"
let defaultBackingAudio = NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource("simple-drum-beat", ofType: "wav")!)




class AVFoundationHelper: NSObject {
    
    let documentsFolderUrl: NSURL
    
    init(completion: (allowed: Bool) -> ()) {
        AVFoundationHelper.initializeAudioSession(completion)
        self.documentsFolderUrl = AVFoundationHelper.getDocumentsFolderUrl()!
    }
    
    static func initializeAudioSession(completion: (allowed: Bool) -> ()) {
        /* Ask for permission to see if we can record audio */
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(AVAudioSessionCategoryPlayAndRecord, withOptions: .DuckOthers)
            do {
                try session.setActive(true)
                print("Successfully activated the audio session")

                session.requestRecordPermission(completion)
            } catch {
                print("Could not activate the audio session")
            }
            
        } catch let error as NSError {
            print("An error occurred in setting the audio session category. Error = \(error)")
        }
    }
    
    // get a URL for the saved recording in the app documents folder
    static func getDocumentsFolderUrl() -> NSURL? {
        let fileManager = NSFileManager.defaultManager()
        let documentsFolderUrl: NSURL?
        do {
            documentsFolderUrl = try fileManager.URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: false)
        } catch let error as NSError {
            print("Error accessing documents folder: \(error)")
            documentsFolderUrl = nil
        }
        
        return documentsFolderUrl
        //return documentsFolderUrl!.URLByAppendingPathComponent("Recording.m4a")
    }
    
    func getDocumentUrl(baseName: String) -> NSURL {
        let uniqueId = NSProcessInfo.processInfo().globallyUniqueString
        let uniqueFileName = "\(baseName)_\(uniqueId).\(defaultAudioExtension)"
        return documentsFolderUrl.URLByAppendingPathComponent(uniqueFileName)
    }
    
    
    // AVAudioRecorder settings
    func audioRecordingSettings() -> [String : AnyObject] {
        return [
            AVFormatIDKey : NSNumber(unsignedInt: kAudioFormatMPEG4AAC),
            AVSampleRateKey : 16000.0 as NSNumber,
            AVNumberOfChannelsKey : 1 as NSNumber,
            AVEncoderAudioQualityKey : AVAudioQuality.Low.rawValue as NSNumber
        ]
    }
    
    
    func isHeadsetConnected() -> Bool {
        let route = AVAudioSession.sharedInstance().currentRoute
        for desc in route.outputs {
            if desc.portType == AVAudioSessionPortHeadphones {
                return true
            }
        }
        return false
    }
    
    
    // combine backing + recording audio into single audio file
    func bounce(backingAudioUrl: NSURL, recordingAudioUrl: NSURL, outputAudioUrl: NSURL, completion: (AVAssetExportSessionStatus, NSError?) -> Void) {
        let composition = AVMutableComposition()
        let backingTrack:AVMutableCompositionTrack = composition.addMutableTrackWithMediaType(AVMediaTypeAudio, preferredTrackID: CMPersistentTrackID())
        let recordingTrack:AVMutableCompositionTrack = composition.addMutableTrackWithMediaType(AVMediaTypeAudio, preferredTrackID: CMPersistentTrackID())
        let insertTime = kCMTimeZero
        
        if backingAudioUrl.checkResourceIsReachableAndReturnError(nil) {
        
        let backingAudio = AVAsset(URL: backingAudioUrl)
        var backingTracks = backingAudio.tracksWithMediaType(AVMediaTypeAudio)
        if !backingTracks.isEmpty {
            do {
                try backingTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, backingAudio.duration), ofTrack: backingTracks[0], atTime: insertTime)
            } catch let error as NSError {
                print("Error adding backing track to composition: \(error)")
            }
        } else {
            print("Backing tracks.count == 0")
        }
            
        } else {
            print("backingAudioURL not reachable: \(backingAudioUrl)")
        }
        
        let recordingAudio = AVAsset(URL: recordingAudioUrl)
        var recordingTracks = recordingAudio.tracksWithMediaType(AVMediaTypeAudio)
        
        if !recordingTracks.isEmpty {
            do {
                try recordingTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, recordingAudio.duration), ofTrack: recordingTracks[0], atTime: insertTime)
            } catch let error as NSError {
                print("Error adding recording track to composition: \(error)")
            }
        } else {
            print("Backing tracks.count == 0")
        }
        
        
        
        let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A)
        if let exporter = exporter {
            exporter.outputURL = outputAudioUrl
            exporter.outputFileType = AVFileTypeAppleM4A
            
            
            exporter.exportAsynchronouslyWithCompletionHandler({
                completion(exporter.status, exporter.error)
            })
            

        }
        
        
    }
    
    
}


protocol AVAudioPlayerExtDelegate: AVAudioPlayerDelegate {
    
    func audioPlayerUpdateTime(player: AVAudioPlayer)
    
}


class AVAudioPlayerExt: AVAudioPlayer {
    
    var updater: CADisplayLink?
    
    override func play() -> Bool {
        if let _ = delegate as? AVAudioPlayerExtDelegate {
            updater = CADisplayLink(target: self, selector: Selector("trackPlayer"))
            updater!.frameInterval = 1
            updater!.addToRunLoop(NSRunLoop.currentRunLoop(), forMode: NSRunLoopCommonModes)
        }
        return super.play()
    }
    
    override func stop() {
        super.stop()
        invalidate()
    }
    
    deinit {
       invalidate()
    }
    
    func invalidate() {
        updater?.invalidate()
    }
    
    func trackPlayer() {
        if let delegate = delegate as? AVAudioPlayerExtDelegate {
            delegate.audioPlayerUpdateTime(self)
        }
    }
    
}


protocol AVAudioRecorderExtDelegate: AVAudioRecorderDelegate {
    
    func audioRecorderUpdateTime(recorder: AVAudioRecorder)
    
}


class AVAudioRecorderExt: AVAudioRecorder {
    
    var updater: CADisplayLink?
    
    override func record() -> Bool {
        if let _ = delegate as? AVAudioRecorderExtDelegate {
            updater = CADisplayLink(target: self, selector: Selector("trackRecorder"))
            updater!.frameInterval = 1
            updater!.addToRunLoop(NSRunLoop.currentRunLoop(), forMode: NSRunLoopCommonModes)
        }
        return super.record()
    }
    
    override func stop() {
        super.stop()
        invalidate()
    }
    
    deinit {
        invalidate()
    }
    
    func invalidate() {
        updater?.invalidate()
    }
    
    func trackPlayer() {
        if let delegate = delegate as? AVAudioRecorderExtDelegate {
            delegate.audioRecorderUpdateTime(self)
        }
    }
    
}

