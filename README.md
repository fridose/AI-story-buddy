Peblo Story Buddy

A kid-friendly Flutter app where a little buddy reads a story aloud, then asks a quiz question with joyful animations, sounds, and feedback.
## Framework choice

I built this challenge using **Flutter** because it lets me:

- Ship a single codebase that runs smoothly on Android (and iOS if needed).
- Combine text-to-speech, animations (Lottie), and custom UI easily.
- Keep performance good on mid-range Android devices by controlling exactly what’s on the screen. [docs.flutter](https://docs.flutter.dev/data-and-backend/state-mgmt/simple)

***

## Audio → quiz transition

Story playback and the quiz are coordinated via `flutter_tts` callbacks:

- When TTS starts, I set `isPlaying = true` in the `StoryQuizViewModel` to show the "listening" state.
- When TTS completes, the `setCompletionHandler` sets:
    - `isPlaying = false`
    - `showQuiz = true`
- The UI listens to these flags via `Provider`:
    - `StoryCard` shows whenever `isPlaying || showQuiz` is true.
    - `QuizWidget` appears only when `showQuiz` is true. [medium.flutterdevs](https://medium.flutterdevs.com/flutter-text-to-speech-3ed66ebec523)

This gives a clean transition from “listening” to “quiz ready” without extra screens.

## Data‑driven quiz design

The quiz is intentionally data-driven rather than hardcoded:

- A `quizJson` map in the viewmodel provides:
    - `question`
    - `options` (list of strings)
    - `answer`
- The viewmodel loads this into fields:

  ```dart
  question = quizJson['question'] as String;
  options = List<String>.from(quizJson['options'] as List);
  correctAnswer = quizJson['answer'] as String;
  ```

- The UI renders buttons by looping over `options`:

  ```dart
  Column(
    children: vm.options.map((opt) {
      // build one button per option
    }).toList(),
  )
  ```

Because the quiz iterates over `options`, it automatically supports different questions and option counts without changing the widget code. [geeksforgeeks](https://www.geeksforgeeks.org/flutter/flutter-outputting-widgets-conditionally/)

In a production setting, this JSON could come from a remote API, local file, or multiple questions.

***

## Caching approach / remote audio

Right now:

- Story audio is generated on-device using `flutter_tts` (no remote audio files).
- Sound effects (`congrats.mp3` and `buzz.mp3`) are small assets bundled in `assets/audio`, effectively cached inside the app bundle. [flutterward.wordpress](https://flutterward.wordpress.com/2021/12/11/play-custom-sound-on-button-press-in-flutter/)

If I needed to cache remote audio in future, I would:

- Download audio files to the app’s documents directory.
- Check for a cached file before hitting the network.
- Use the same `AudioPlayer` instance to play from local paths, avoiding repeated downloads.

This keeps network usage low and avoids stutters on slow connections.

***

## Audio loading and failure states

**Text‑to‑speech:**

- I initialize `flutter_tts` with language, speech rate, and volume.
- I set three handlers:
    - `setStartHandler`: marks `isPlaying = true`.
    - `setCompletionHandler`: marks `isPlaying = false` and `showQuiz = true`.
    - `setErrorHandler`: sets `hasError = true` and saves `errorMessage`. [medium.flutterdevs](https://medium.flutterdevs.com/flutter-text-to-speech-3ed66ebec523)

**SFX audio (congrats & buzz):**

- A single `AudioPlayer` instance is reused for all sound effects.
- Before any sound, I call `_audioPlayer.stop()` to avoid overlapping audio.
- SFX are loaded via `AssetSource('audio/congrats.mp3')` and `AssetSource('audio/buzz.mp3')`, with try/catch to avoid crashing if an asset fails. [apparencekit](https://apparencekit.dev/flutter-tips/how-to-play-sounds-in-flutter/)

The UI uses a `StatusCard` (optional) to show friendly error messages if TTS fails.

***

## Performance profiling

I profiled the app using Flutter’s DevTools in **profile** mode: [docs.flutter](https://docs.flutter.dev/perf/ui-performance)

1. Ran the app:

   ```bash
   flutter run --profile
   ```

2. Opened DevTools Performance view and recorded a session covering:
    - Story playback.
    - Quiz appearance.
    - Wrong answer (shake + buzz).
    - Right answer (confetti + congrats).

3. Observations:
    - Frame times stayed under the 16ms budget on a mid‑range Android emulator.
    - No red “jank” bars during normal interaction.
    - The biggest spikes came from initial Lottie load, but they were still within acceptable limits.

I’ve included a frame‑timing screenshot in the repo (e.g. `docs/perf.png`) showing smooth frame timings.

***

## Keeping it lightweight on mid-range Android

To keep the app friendly for modest devices, I made these choices: [tothenew](https://www.tothenew.com/blog/a-guide-on-optimising-and-improving-you-flutter-app-performance-by-using-flutter-dev-tools/)

- **Simple architecture:** One main screen with `Provider` + `ChangeNotifier` instead of heavy state management.
- **Single audio player:** Reuse one `AudioPlayer` instance for all SFX to avoid multiple audio pipelines.
- **Light animations:**
    - One Lottie bear animation at a time (default / listening / happy / sad).
    - Simple scale/bounce and shake animations; no complex physics or many overlapping animations.
- **Minimal rebuilds:** The UI listens to a small set of boolean flags (`isPlaying`, `showQuiz`, `isCorrect`, `lastAnswerWrong`) so state changes are cheap.

This combination keeps memory and CPU usage low while still feeling joyful.

***

## AI usage & judgment

I used AI assistance (Perplexity) during development to:

- Set up the `ChangeNotifier` viewmodel and `Provider` wiring.
- Integrate `flutter_tts`, `audioplayers`, confetti, and Lottie animations. [apparencekit](https://apparencekit.dev/flutter-tips/how-to-play-sounds-in-flutter/)

**One suggestion I changed/rejected:**

- Initially, the avatar used simple emoji characters (🙂/☹️) inside a `CircleAvatar`. I later replaced this with my own kid-friendly bear Lottie animations for default, listening, happy, and sad states to better match Peblo’s style.
- Another suggestion was to fully lock the quiz after a correct answer and ignore all further taps. I adjusted this so that:
    - Tapping a wrong option after a correct one stops the congrats sound and plays the buzz, giving clearer feedback.
    - The quiz logic still remains simple and predictable for kids.

**Things that didn’t work at first and how I fixed them:**

- **Audio assets not playing:**  
  At first, `congrats.mp3` and `buzz.mp3` didn’t play because the asset paths in `pubspec.yaml` didn’t match the `AssetSource` paths. I fixed it by:
    - Ensuring assets are listed as `assets/audio/congrats.mp3` and using `AssetSource('audio/congrats.mp3')`.
- **Avatar assets not loading:**  
  I had mismatches between file names (e.g., `listen.svg` vs `reading.svg` / JSON). Fixing the file names and keeping code + `pubspec.yaml` in sync resolved this.

***

## Screen recording

The repo includes a short screen recording (e.g. `docs/demo.mp4`) showing the full flow:

1. Default screen: welcome bear + “Read Me a Story” button.
2. Tapping “Read Me a Story”:
    - Listening bear animation.
    - Story text appears while TTS reads out.
3. When audio ends:
    - Quiz card appears with question and options.
4. Wrong answer:
    - Quiz card shakes.
    - Bear turns sad.
    - Buzz sound plays.
5. Right answer:
    - Confetti animation.
    - Congrats sound plays.
    - Bear turns happy.

This demonstrates the state transitions and feedback loop end-to-end.

***

## How to run

```bash
flutter pub get
flutter run
```

Requirements:

- Flutter SDK (3.3.0 or later).
- Android emulator or device (mid-range spec or better).
