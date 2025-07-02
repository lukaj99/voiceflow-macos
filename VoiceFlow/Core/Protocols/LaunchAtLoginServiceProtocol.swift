import Foundation
import Combine

/// Protocol defining the interface for managing launch at login functionality
@MainActor
public protocol LaunchAtLoginServiceProtocol: AnyObject, ObservableObject, Sendable {
    
    // MARK: - Properties
    
    var isEnabled: Bool { get }
    
    // MARK: - Methods
    
    func enable()
    func disable()
    func toggle()
}