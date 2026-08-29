# PocketProfessor

PocketProfessor is a Flutter learning assistant with an on-device AI chat system. It helps users ask questions, continue conversations, and save useful facts in private local memory.

## Features

- Local AI chat with streaming responses
- Conversation history stored on the device
- Saved memory facts that can be added and removed
- Background model download and preparation
- Resumable downloads for interrupted model setup
- Adjustable context size, response length, and temperature
- Dark Aurora Glass interface

## Technology

- Flutter and Dart
- Riverpod for state management
- GoRouter for navigation
- SQLite for conversations, messages, and memory
- Shared Preferences for local settings
- `llama_cpp_dart` for on-device GGUF model inference
- Qwen 2.5 Instruct Q4_K_M model

## Requirements

- Flutter SDK with Dart 3.12 or newer
- Android Studio for Android development, or Xcode for iOS development
- Internet access on first launch to download the AI model
- At least 1 GB of free storage for the optional large model

## Run the app

```bash
flutter pub get
flutter run
```

On first launch, the app downloads the default Qwen 2.5 0.5B model, approximately 491 MB. The download runs in the background and can resume after an interruption.

To use the larger 1.5B model instead:

```bash
flutter run --dart-define=LARGE_MODEL=true
```

## Test

```bash
flutter test
```

## Project structure

```text
lib/ai/          AI model runtime and downloading
lib/core/        Theme, services, models, and constants
lib/database/    SQLite database setup
lib/features/    Chat, home, intro, memory, settings, and splash screens
test/            Unit and widget tests
```

## Privacy

After the model is downloaded, AI generation runs locally on the device. Conversations, settings, and memory facts are stored locally by the app.

## Model files

The GGUF model is intentionally excluded from Git because GitHub does not accept files larger than 100 MB. The app downloads the model from Hugging Face when it is needed.

## Status

PocketProfessor is under active development.
