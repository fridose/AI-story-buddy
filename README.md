# Peblo Story Buddy

A kid-friendly Flutter app where a little buddy reads a story aloud, then asks a quiz question with joyful animations, sounds, and feedback.

## Demo video

[Watch demo video](https://github.com/user-attachments/assets/e7ef873f-b254-42ae-a234-e0e6ab758a65)

## Overview

Peblo Story Buddy is designed for young kids to practice listening comprehension in a playful way:

- The app reads a short story using text-to-speech.
- A multiple-choice quiz appears when the story finishes.
- Kids get clear audio/visual feedback for both wrong and right answers.

## Why Flutter

I chose **Flutter** because it:

- Uses one codebase for Android and iOS.
- Makes it easy to combine text-to-speech, animations (Lottie), and custom UI.
- Offers good performance on mid-range devices with fine-grained control over rendering. [freecodecamp](https://www.freecodecamp.org/news/how-to-write-a-good-readme-file/)

## Core flow

- Home screen shows a friendly animation and a **“Read Me a Story”** call-to-action.
- Tapping the button:
  - Starts TTS playback of the story.
  - Switches the idle animation into a “listening” animation.
- When audio ends:
  - A quiz card fades in with a question and options.
- Wrong answer:
  - Card shake animation.
  - Sad animation state.
  - Short buzz sound.
- Correct answer:
  - Confetti animation.
  - Happy animation  state.
  - Short “cheering” sound.

## Implementation details

- **State management:** `ChangeNotifier` + `Provider` for a single-screen flow.
- **Audio:**
  - Story uses `flutter_tts` with start/completion handlers.
  - SFX use a shared `AudioPlayer` instance and small bundled assets.
- **Quiz:**
  - Driven by a map (question, options, correct answer).
  - UI renders buttons by iterating over `options`, so it’s easy to plug in new questions.
- **Animations:**
  - Lottie animations for idle, listening, happy, and sad.
  - Simple shake & bounce effects for quiz feedback.

## Performance

To keep the experience smooth on mid-range Android:

- The app runs in **profile** mode for testing (Flutter DevTools).
- Only one main screen and a small set of boolean flags drive the UI.
- A single audio player is reused for all sound effects.
- Only one bear animation is active at a time to keep GPU/CPU load low. [utrechtuniversity.github](https://utrechtuniversity.github.io/workshop-computational-reproducibility/chapters/readme-files.html)

## AI & iteration

I used AI assistance (Perplexity) to:

- Wire up `ChangeNotifier` + `Provider`.
- Integrate `flutter_tts`, `audioplayers`, confetti.

Then I customized:

- Replacing simple emoji avatars with custom bear animations to better match Peblo’s kid-friendly style.
- Tuning quiz behavior so feedback stays clear even if kids keep tapping options.

## How to run

```bash
flutter pub get
flutter run
```

Requirements:

- Flutter SDK 3.3.0 or later.
- Android emulator or device.






