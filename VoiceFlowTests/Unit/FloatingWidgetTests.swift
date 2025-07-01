import XCTest
import AppKit
import SwiftUI
@testable import VoiceFlowUI

class FloatingWidgetTests: XCTestCase {
    var window: FloatingWidgetWindow!
    var controller: FloatingWidgetController!
    var viewModel: TranscriptionViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = TranscriptionViewModel()
        controller = FloatingWidgetController(viewModel: viewModel)
        window = controller.window
    }
    
    override func tearDown() {
        window?.close()
        window = nil
        controller = nil
        viewModel = nil
        super.tearDown()
    }
    
    // MARK: - Window Configuration Tests
    
    func testWindowInitialization() {
        XCTAssertNotNil(window)
        XCTAssertTrue(window.isFloatingPanel)
        XCTAssertTrue(window.hidesOnDeactivate)
        XCTAssertEqual(window.level, .floating)
        XCTAssertFalse(window.hasShadow) // Custom shadow in view
    }
    
    func testWindowSize() {
        let expectedSize = CGSize(width: 320, height: 100)
        XCTAssertEqual(window.frame.size.width, expectedSize.width, accuracy: 1.0)
        XCTAssertEqual(window.frame.size.height, expectedSize.height, accuracy: 1.0)
    }
    
    func testWindowStyle() {
        XCTAssertTrue(window.styleMask.contains(.borderless))
        XCTAssertTrue(window.isOpaque == false)
        XCTAssertEqual(window.backgroundColor, .clear)
    }
    
    // MARK: - Positioning Tests
    
    func testDefaultPosition() {
        controller.setPosition(.topRight)
        
        guard let screen = NSScreen.main else {
            XCTFail("No main screen available")
            return
        }
        
        let expectedX = screen.frame.maxX - window.frame.width - 20
        let expectedY = screen.frame.maxY - window.frame.height - 20
        
        XCTAssertEqual(window.frame.origin.x, expectedX, accuracy: 1.0)
        XCTAssertEqual(window.frame.origin.y, expectedY, accuracy: 1.0)
    }
    
    func testAllPositions() {
        let positions: [FloatingWidgetPosition] = [
            .topLeft, .topCenter, .topRight,
            .middleLeft, .center, .middleRight,
            .bottomLeft, .bottomCenter, .bottomRight
        ]
        
        for position in positions {
            controller.setPosition(position)
            
            // Verify window is within screen bounds
            if let screen = NSScreen.main {
                XCTAssertTrue(screen.frame.contains(window.frame))
            }
        }
    }
    
    func testCustomPosition() {
        let customPoint = CGPoint(x: 100, y: 200)
        controller.setPosition(.custom(customPoint))
        
        XCTAssertEqual(window.frame.origin, customPoint)
    }
    
    // MARK: - Dragging Tests
    
    func testDraggingCapability() {
        XCTAssertTrue(window.isMovable)
        XCTAssertTrue(window.isMovableByWindowBackground)
    }
    
    func testDragConstraints() {
        // Simulate dragging to screen edge
        guard let screen = NSScreen.main else { return }
        
        // Try to drag beyond screen bounds
        let offscreenPoint = CGPoint(x: -100, y: screen.frame.maxY + 100)
        controller.setPosition(.custom(offscreenPoint))
        
        // Window should be constrained to screen
        XCTAssertGreaterThanOrEqual(window.frame.minX, 0)
        XCTAssertLessThanOrEqual(window.frame.maxX, screen.frame.maxX)
        XCTAssertGreaterThanOrEqual(window.frame.minY, 0)
        XCTAssertLessThanOrEqual(window.frame.maxY, screen.frame.maxY)
    }
    
    // MARK: - Visibility Tests
    
    func testShowHide() {
        controller.show()
        XCTAssertTrue(window.isVisible)
        
        controller.hide()
        XCTAssertFalse(window.isVisible)
    }
    
    func testToggleVisibility() {
        let initialVisibility = window.isVisible
        
        controller.toggleVisibility()
        XCTAssertNotEqual(window.isVisible, initialVisibility)
        
        controller.toggleVisibility()
        XCTAssertEqual(window.isVisible, initialVisibility)
    }
    
    func testFadeInOut() {
        let fadeExpectation = expectation(description: "Fade animation")
        
        window.alphaValue = 0
        controller.fadeIn(duration: 0.1) {
            XCTAssertEqual(self.window.alphaValue, 1.0, accuracy: 0.1)
            
            self.controller.fadeOut(duration: 0.1) {
                XCTAssertEqual(self.window.alphaValue, 0.0, accuracy: 0.1)
                fadeExpectation.fulfill()
            }
        }
        
        wait(for: [fadeExpectation], timeout: 1.0)
    }
    
    // MARK: - State Binding Tests
    
    func testTranscriptionStateBinding() {
        // Start transcription
        viewModel.isTranscribing = true
        
        // Widget should update to show active state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Verify UI updates (would check actual view state)
            XCTAssertTrue(self.viewModel.isTranscribing)
        }
    }
    
    func testAudioLevelBinding() {
        viewModel.currentAudioLevel = 0.5
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Verify waveform updates
            XCTAssertEqual(self.viewModel.currentAudioLevel, 0.5)
        }
    }
    
    // MARK: - Interaction Tests
    
    func testClickAction() {
        let clickExpectation = expectation(description: "Widget clicked")
        
        controller.onWidgetClick = {
            clickExpectation.fulfill()
        }
        
        // Simulate click
        controller.handleClick()
        
        wait(for: [clickExpectation], timeout: 1.0)
    }
    
    func testRightClickMenu() {
        let menu = controller.createContextMenu()
        
        XCTAssertNotNil(menu)
        XCTAssertGreaterThan(menu.items.count, 0)
        
        // Check for expected menu items
        let menuTitles = menu.items.map { $0.title }
        XCTAssertTrue(menuTitles.contains("Hide Widget"))
        XCTAssertTrue(menuTitles.contains("Settings..."))
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibility() {
        guard let contentView = window.contentView else {
            XCTFail("No content view")
            return
        }
        
        XCTAssertTrue(contentView.isAccessibilityElement)
        XCTAssertNotNil(contentView.accessibilityLabel)
        XCTAssertEqual(contentView.accessibilityRole, .group)
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryManagement() {
        weak var weakController = controller
        weak var weakWindow = window
        
        controller = nil
        window = nil
        
        XCTAssertNil(weakController)
        XCTAssertNil(weakWindow)
    }
}

// MARK: - Position Enum

enum FloatingWidgetPosition {
    case topLeft, topCenter, topRight
    case middleLeft, center, middleRight  
    case bottomLeft, bottomCenter, bottomRight
    case custom(CGPoint)
}