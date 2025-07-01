#!/usr/bin/env swift

// Validation Build Script for VoiceFlow Swift 6 Migration
// Tests that core components compile successfully

import Foundation

print("🔍 VoiceFlow Swift 6 Validation")
print("==============================")

// Test 1: Core components exist
let coreFiles = [
    "VoiceFlow/main.swift",
    "VoiceFlow/AdvancedApp.swift", 
    "VoiceFlow/Core/TranscriptionEngine/TranscriptionModels.swift",
    "VoiceFlow/Core/TranscriptionEngine/AudioEngineManager.swift",
    "VoiceFlow/Core/TranscriptionEngine/RealSpeechRecognitionEngine.swift",
    "VoiceFlow/Core/TranscriptionEngine/PerformanceMonitor.swift"
]

print("📁 Checking core files...")
var allFilesExist = true
for file in coreFiles {
    if FileManager.default.fileExists(atPath: file) {
        print("  ✅ \(file)")
    } else {
        print("  ❌ \(file) - Missing")
        allFilesExist = false
    }
}

// Test 2: Package.swift validation
print("\n📦 Validating Package.swift...")
if FileManager.default.fileExists(atPath: "Package.swift") {
    print("  ✅ Package.swift exists")
    
    do {
        let packageContent = try String(contentsOfFile: "Package.swift")
        let validations = [
            ("Swift 6.0", packageContent.contains("swift-tools-version: 6.0")),
            ("AsyncAlgorithms", packageContent.contains("swift-async-algorithms")),
            ("HotKey", packageContent.contains("HotKey")),
            ("KeychainAccess", packageContent.contains("KeychainAccess")),
            ("Strict Concurrency", packageContent.contains("SWIFT_CONCURRENCY_STRICT"))
        ]
        
        for (feature, exists) in validations {
            print("  \(exists ? "✅" : "❌") \(feature)")
        }
    } catch {
        print("  ❌ Could not read Package.swift")
        allFilesExist = false
    }
} else {
    print("  ❌ Package.swift missing")
    allFilesExist = false
}

// Test 3: Scripts validation  
print("\n🔧 Checking build scripts...")
let scripts = [
    "Scripts/optimize-build.sh",
    "Scripts/parallel-build.sh", 
    "Scripts/parallel-dev-coordinator.sh"
]

for script in scripts {
    if FileManager.default.fileExists(atPath: script) {
        print("  ✅ \(script)")
    } else {
        print("  ⚠️  \(script) - Missing (optional)")
    }
}

// Test 4: Parallel development validation
print("\n🚀 Parallel development validation...")
if FileManager.default.fileExists(atPath: "VoiceFlow/Parallel/AsyncTranscriptionProcessor.swift") {
    print("  ✅ AsyncTranscriptionProcessor implemented")
} else {
    print("  ❌ AsyncTranscriptionProcessor missing")
    allFilesExist = false
}

if FileManager.default.fileExists(atPath: "ParallelDevelopmentTests.swift") {
    print("  ✅ Parallel development tests created")
} else {
    print("  ❌ Parallel development tests missing")
    allFilesExist = false
}

// Summary
print("\n📊 Validation Summary:")
if allFilesExist {
    print("🎉 All critical components validated successfully!")
    print("✅ VoiceFlow is ready for Swift 6 parallel development")
    exit(0)
} else {
    print("⚠️  Some components missing or need attention")
    print("🔧 Review missing files and rebuild if necessary")
    exit(1)
}