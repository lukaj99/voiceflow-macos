import Foundation
import ServiceManagement

/// Service for managing launch at login functionality
@MainActor
public final class LaunchAtLoginService: ObservableObject {
    
    // MARK: - Properties
    
    @Published public private(set) var isEnabled = false
    
    private let launcherBundleIdentifier = "com.voiceflow.mac.launcher"
    
    // MARK: - Initialization
    
    public init() {
        checkCurrentStatus()
    }
    
    // MARK: - Public Methods
    
    public func enable() {
        do {
            try SMAppService.mainApp.register()
            isEnabled = true
            UserDefaults.standard.set(true, forKey: "LaunchAtLogin")
        } catch {
            print("Failed to enable launch at login: \(error)")
            isEnabled = false
        }
    }
    
    public func disable() {
        do {
            try SMAppService.mainApp.unregister()
            isEnabled = false
            UserDefaults.standard.set(false, forKey: "LaunchAtLogin")
        } catch {
            print("Failed to disable launch at login: \(error)")
        }
    }
    
    public func toggle() {
        if isEnabled {
            disable()
        } else {
            enable()
        }
    }
    
    // MARK: - Private Methods
    
    private func checkCurrentStatus() {
        // Check if the service is currently registered
        isEnabled = SMAppService.mainApp.status == .enabled
        
        // Sync with UserDefaults
        UserDefaults.standard.set(isEnabled, forKey: "LaunchAtLogin")
    }
}

// MARK: - Legacy Support

extension LaunchAtLoginService {
    
    /// Legacy method for older macOS versions that don't support SMAppService
    private func legacyEnable() {
        let identifier = Bundle.main.bundleIdentifier ?? "com.voiceflow.mac"
        let launcherPath = Bundle.main.bundlePath + "/Contents/Library/LoginItems/VoiceFlowLauncher.app"
        
        // Create login item
        if let loginItems = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems, nil) {
            let loginItemURL = URL(fileURLWithPath: launcherPath)
            LSSharedFileListInsertItemURL(
                loginItems.takeRetainedValue(),
                kLSSharedFileListItemBeforeFirst,
                nil,
                nil,
                loginItemURL as CFURL,
                nil,
                nil
            )
        }
        
        isEnabled = true
        UserDefaults.standard.set(true, forKey: "LaunchAtLogin")
    }
    
    private func legacyDisable() {
        if let loginItems = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems, nil) {
            let loginItemsArray = LSSharedFileListCopySnapshot(loginItems.takeRetainedValue(), nil)
            let items = loginItemsArray.takeRetainedValue() as [LSSharedFileListItem]
            
            for item in items {
                var resolutionFlags = UInt32(kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes)
                let url = LSSharedFileListItemCopyResolvedURL(item, resolutionFlags, nil)
                
                if let path = url?.takeRetainedValue().path,
                   path.contains("VoiceFlow") {
                    LSSharedFileListItemRemove(loginItems.takeRetainedValue(), item)
                    break
                }
            }
        }
        
        isEnabled = false
        UserDefaults.standard.set(false, forKey: "LaunchAtLogin")
    }
}