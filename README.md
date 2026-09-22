# LocalAI

A native macOS local AI client built with SwiftUI and powered by Ollama.

## Current Status

V1 is a basic chat interface connected to a locally running Ollama server.

## Stack

- SwiftUI
- Ollama
- Qwen3 8B
- URLSession

## Requirements

- macOS
- Xcode
- Ollama
- Qwen3 8B

## Running

Start Ollama and make sure Qwen3 8B is installed:

    ollama run qwen3:8b

Then open the Xcode project and run the application.

The app connects to the local Ollama API at http://127.0.0.1:11434.

## Roadmap

- [x] Basic SwiftUI interface
- [x] Ollama connection
- [x] Local Qwen3 inference
- [ ] Conversation history
- [ ] Streaming responses
- [ ] Stop generation
- [ ] Multiple model support
- [ ] File context
- [ ] PDF/document understanding
- [ ] Tool calling
