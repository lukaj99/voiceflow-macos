# LLM Post-Processing Integration Guide

## Overview

VoiceFlow now includes advanced LLM-powered post-processing capabilities that enhance transcription accuracy through:

- **Grammar and punctuation correction**
- **Word substitution** (e.g., "slash" → "/", "at sign" → "@")
- **Capitalization fixes**
- **Context-aware improvements**
- **Formatting enhancements**

## Supported LLM Providers

### OpenAI GPT
- **GPT-4o Mini** (Recommended) - Fast, cost-effective, excellent for transcription enhancement
- **GPT-4o** - More powerful, higher accuracy for complex corrections

### Anthropic Claude
- **Claude 3 Haiku** (Recommended) - Fast, cost-effective, great performance
- **Claude 3 Sonnet** - More sophisticated understanding for complex text

## Setup Instructions

### 1. Configure API Keys

#### Option A: Through Settings UI
1. Open VoiceFlow
2. Go to Settings → LLM Enhancement
3. Click "Configure LLM API Keys"
4. Select your preferred provider (OpenAI or Claude)
5. Enter your API key
6. Test the configuration

#### Option B: Programmatic Configuration
```swift
import VoiceFlow

// Configure OpenAI
let credentialService = SecureCredentialService()
try await credentialService.configureLLMAPIKey(from: "sk-your-openai-key", for: .openAI)

// Configure Claude
try await credentialService.configureLLMAPIKey(from: "sk-ant-your-claude-key", for: .claude)
```

### 2. Enable LLM Post-Processing

#### Through Settings UI
1. Go to Settings → LLM Enhancement
2. Toggle "Enable LLM Post-Processing"
3. Select your preferred provider and model
4. Configure processing options

#### Programmatically
```swift
// Enable LLM processing
AppState.shared.enableLLMPostProcessing()

// Set provider and model
AppState.shared.setSelectedLLMProvider("openai", model: "gpt-4o-mini")
```

## Configuration Options

### Model Selection
Choose the appropriate model based on your needs:

| Model | Speed | Cost | Accuracy | Best For |
|-------|-------|------|----------|----------|
| GPT-4o Mini | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | General transcription |
| GPT-4o | ⭐⭐ | ⭐ | ⭐⭐⭐ | Complex technical content |
| Claude 3 Haiku | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | General transcription |
| Claude 3 Sonnet | ⭐⭐ | ⭐⭐ | ⭐⭐⭐ | Complex contextual understanding |

### Processing Settings
```swift
let llmService = LLMPostProcessingService()

// Basic configuration
llmService.selectedModel = .gpt4oMini
llmService.isEnabled = true

// Advanced settings
llmService.maxTokens = 1000              // Maximum response length
llmService.temperature = 0.1             // Low for consistent corrections
llmService.useContextualCorrection = true    // Enable context awareness
llmService.enableWordSubstitution = true     // Enable word replacements
```

## Usage Examples

### Basic Usage
```swift
let processor = TranscriptionTextProcessor()

// Process transcribed text
let originalText = "hello world this is a test with slash symbol"
let enhancedText = await processor.processTranscript(originalText, isFinal: true)
// Result: "Hello world, this is a test with / symbol."
```

### Word Substitution Examples
The system automatically handles common spoken symbols:

| Spoken | Symbol | Example |
|--------|---------|---------|
| "slash" | "/" | "website slash page" → "website/page" |
| "at sign" | "@" | "email at sign domain" → "email@domain" |
| "hashtag" | "#" | "hashtag trending" → "#trending" |
| "dollar sign" | "$" | "dollar sign price" → "$price" |
| "percent" | "%" | "fifty percent" → "50%" |
| "ampersand" | "&" | "this ampersand that" → "this & that" |

### Domain-Aware Processing
The system automatically detects content domains and provides appropriate context:

```swift
// Medical terminology
let medicalText = "patient has hypertension and diabetes"
// Enhanced: "Patient has hypertension and diabetes."

// Technical content
let techText = "initialize the array with null values"
// Enhanced: "Initialize the array with null values."

// Legal content
let legalText = "the plaintiff filed a motion to dismiss"
// Enhanced: "The plaintiff filed a motion to dismiss."
```

## Performance Features

### Caching
- **Request caching** prevents duplicate API calls for identical text
- **Cache size limit** (100 entries by default) for memory efficiency
- **Automatic cache expiration** for optimal performance

### Processing Optimization
- **Async processing** doesn't block the transcription pipeline
- **Error recovery** gracefully handles API failures
- **Progress tracking** provides real-time status updates

### Statistics Tracking
```swift
let stats = AppState.shared.llmProcessingStats

print("Total processed: \(stats.totalProcessed)")
print("Success rate: \(stats.successRate * 100)%")
print("Average processing time: \(stats.averageProcessingTime)s")
print("Average improvement score: \(stats.averageImprovementScore)")
```

## Integration Architecture

### Data Flow
```
Audio Input → Deepgram Transcription → Text Processor → LLM Enhancement → Final Output
                                            ↓
                                    Domain Detection
                                            ↓
                                    Context Building
                                            ↓
                                    API Call (Cached)
                                            ↓
                                    Change Analysis
```

### Components

#### LLMPostProcessingService
- Handles API communication with OpenAI and Claude
- Manages caching and performance optimization
- Provides error handling and retry logic

#### TranscriptionTextProcessor
- Integrates LLM processing into transcription pipeline
- Manages domain detection and context building
- Coordinates with AppState for status updates

#### SecureCredentialService
- Securely stores and manages LLM API keys
- Provides validation and testing capabilities
- Supports multiple provider configurations

## Error Handling

### Common Errors and Solutions

#### API Key Issues
```swift
// Error: LLM API key is missing
// Solution: Configure API key in settings

// Error: Invalid API key format
// Solution: Verify key format matches provider requirements
```

#### Rate Limiting
```swift
// Error: Rate limit exceeded
// Solution: Implement exponential backoff or upgrade API plan

// Automatic retry with backoff is built-in
```

#### Network Issues
```swift
// Error: Network timeout
// Solution: Check internet connection, service automatically retries

// Error: Service unavailable
// Solution: Temporary issue, will resolve automatically
```

## Best Practices

### API Key Management
- Store keys securely using SecureCredentialService
- Never hardcode API keys in source code
- Use environment variables for development
- Regularly rotate API keys for security

### Performance Optimization
- Choose appropriate models for your use case
- Monitor processing statistics
- Enable caching for repeated content
- Consider batch processing for high-volume scenarios

### Error Handling
- Always implement fallback to original text
- Monitor error rates and adjust accordingly
- Provide clear user feedback for configuration issues
- Log errors for debugging and monitoring

## Monitoring and Analytics

### Built-in Metrics
```swift
// Access processing statistics
let stats = AppState.shared.llmProcessingStats

// Key metrics to monitor:
// - Success rate (should be > 95%)
// - Average processing time (should be < 2s)
// - Improvement score (indicates enhancement quality)
// - Error frequency (should be minimal)
```

### Performance Monitoring
```swift
// Enable performance monitoring
let performanceMonitor = PerformanceMonitor()
performanceMonitor.trackLLMProcessing = true

// Monitor key indicators:
// - API response times
// - Cache hit rates
// - Memory usage
// - Network bandwidth
```

## Troubleshooting

### Common Issues

#### LLM Processing Not Working
1. Check if LLM processing is enabled in settings
2. Verify API key is configured correctly
3. Ensure network connectivity
4. Check for any error messages in the UI

#### Poor Enhancement Quality
1. Try a different model (e.g., GPT-4o instead of GPT-4o Mini)
2. Check if domain detection is working correctly
3. Verify input text quality from transcription
4. Monitor improvement scores in statistics

#### Performance Issues
1. Check cache hit rates
2. Monitor API response times
3. Consider reducing maxTokens for faster processing
4. Verify network connection quality

### Debug Information
```swift
// Enable debug logging
print("LLM Service Status:")
print("- Enabled: \(llmService.isEnabled)")
print("- Model: \(llmService.selectedModel)")
print("- Configured Providers: \(llmService.getAvailableModels())")
print("- Cache Size: \(llmService.cacheSize)")
print("- Statistics: \(llmService.getStatistics())")
```

## API Costs and Optimization

### Cost Management
- **GPT-4o Mini**: ~$0.0015 per 1K tokens (most cost-effective)
- **GPT-4o**: ~$0.03 per 1K tokens (higher quality)
- **Claude 3 Haiku**: ~$0.0015 per 1K tokens (cost-effective)
- **Claude 3 Sonnet**: ~$0.015 per 1K tokens (balanced cost/quality)

### Optimization Tips
1. Use recommended models for general transcription
2. Enable caching to reduce duplicate requests
3. Monitor token usage and adjust maxTokens accordingly
4. Consider processing only final transcriptions, not interim results

## Security Considerations

### API Key Security
- Keys are stored encrypted in macOS Keychain
- Never logged or transmitted in plain text
- Automatic key validation and format checking
- Support for key rotation without app restart

### Data Privacy
- No transcription data is stored by LLM providers (when configured properly)
- Processing happens in real-time without data retention
- All communication uses HTTPS encryption
- Support for on-premises LLM deployment (future enhancement)

## Future Enhancements

### Planned Features
- **Custom prompts** for specialized domains
- **Batch processing** for high-volume scenarios
- **Local LLM support** for offline processing
- **Advanced context awareness** using conversation history
- **Multi-language support** for international users
- **Performance auto-tuning** based on usage patterns

### Contributing
We welcome contributions to improve LLM integration:
- Report issues and suggestions
- Submit pull requests for enhancements
- Share usage patterns and optimization tips
- Help with testing and validation

---

For technical support or questions, please refer to the main VoiceFlow documentation or submit an issue on GitHub. 