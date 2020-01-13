//
//  AppDelegate.swift
//  LivePlayeriOS
//
//  Created by voodoo on 2019/12/4.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import UIKit
import AVFoundation


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    var audioSessionObserver: Any!
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Observe AVAudioSession notifications.
        
        // Note that a real app might need to observe other AVAudioSession notifications, too,
        // especially if it needs to properlay handle playback interruptions when the app is
        // in the background.
        let notificationCenter = NotificationCenter.default
        
        audioSessionObserver = notificationCenter.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification,
                                                              object: nil,
                                                              queue: nil) { [unowned self] _ in
            self.setUpAudioSession()
        }
        
        // Configure the audio session initially.
        setUpAudioSession()
        // Override point for customization after application launch.
        return true
    }

    // A helper method that configures the app's audio session.
    // Note that the `.longForm` policy indicates that the app's audio output should use AirPlay 2
    // for playback.
    /// - Tag: LongForm
    private func setUpAudioSession() {
        if #available(iOS 11.0, *) {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, policy: .longFormAudio)
            } catch {
                print("Failed to set audio session route sharing policy: \(error)")
            }
        } else if #available(iOS 10.0, *) {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            } catch {
                print("Failed to set audio session route sharing policy: \(error)")
            }
        } else if #available(iOS 6.0, *) {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback)
            } catch {
                print("Failed to set audio session route sharing policy: \(error)")
            }
        }
    }

    
    func applicationDidEnterBackground(_ application: UIApplication) {
        print("applicationDidEnterBackground")
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        print("applicationDidBecomeActive")
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        print("applicationWillResignActive")
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        print("applicationWillTerminate")
    }
    
    func applicationDidFinishLaunching(_ application: UIApplication) {
        print("applicationDidFinishLaunching")
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        print("applicationWillEnterForeground")
    }
    
    func applicationSignificantTimeChange(_ application: UIApplication) {
        print("applicationSignificantTimeChange")
    }
    
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        print("applicationDidReceiveMemoryWarning")
    }
    
    
}

