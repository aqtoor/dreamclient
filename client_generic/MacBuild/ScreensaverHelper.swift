//
//  ScreensaverHelper.swift
//  infinidream
//
//  Objective-C bridge for PaperSaver functionality
//

import Foundation
import PaperSaver

@objc public class ScreensaverHelper: NSObject {
    private let paperSaver = PaperSaver()
    
    @objc nonisolated(unsafe) public static let shared = ScreensaverHelper()
    
    private override init() {
        super.init()
    }
    
    /// Check if infinidream is the currently active screensaver
    @objc public func isInfinidreamActive() -> Bool {
        guard let activeScreensaver = paperSaver.getActiveScreensaver() else {
            return false
        }
        // Check if the identifier matches infinidream
        return activeScreensaver.identifier == "infinidream"
    }
    
    /// Set infinidream as the active screensaver
    @objc public func setInfinidreamAsActive(completion: @escaping (Bool, Error?) -> Void) {
        Task {
            do {
                // Use "infinidream" as the module name
                try await paperSaver.setScreensaver(module: "infinidream")
                await MainActor.run {
                    completion(true, nil)
                }
            } catch {
                await MainActor.run {
                    completion(false, error)
                }
            }
        }
    }
    
    /// Check if any screensaver (not just infinidream) is installed
    @objc public func hasActiveScreensaver() -> Bool {
        return paperSaver.getActiveScreensaver() != nil
    }
    
    /// Get the name of the currently active screensaver
    @objc public func getActiveScreensaverName() -> String? {
        return paperSaver.getActiveScreensaver()?.name
    }
}
