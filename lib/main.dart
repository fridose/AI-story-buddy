import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => StoryQuizViewModel(),
      child: const PebloApp(),
    ),
  );
}

class PebloApp extends StatelessWidget {
  const PebloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: ' AI Story Buddy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const StoryBuddyScreen(),
    );
  }
}

// Now we have 4 moods: default, reading, happy, sad
enum BuddyMood { defaultMood, reading, happy, sad }

class StoryQuizViewModel extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();

  bool isPreparingAudio = false;
  bool isPlaying = false;
  bool hasError = false;
  String? errorMessage;
  bool lastAnswerWrong = false;

  bool showQuiz = false;
  bool isCorrect = false;
  bool shouldShake = false;
  bool celebrate = false;
  String? selectedOption;

  final ConfettiController confettiController =
  ConfettiController(duration: const Duration(seconds: 2));

  final String storyText =
      'Once upon a time, a clever little robot named Pip lost his shiny blue gear in the Whispering Woods...';

  final AudioPlayer _audioPlayer = AudioPlayer();

  late final String question;
  late final List<String> options;
  late final String correctAnswer;

  StoryQuizViewModel() {
    _loadQuizFromJson();
    _initTts();
  }

  // Buddy mood getter:
  // default screen -> defaultMood
  // while reading -> reading
  // correct answer -> happy
  // wrong answer -> sad
  BuddyMood get buddyMood {
    if (isPlaying) return BuddyMood.reading;
    if (isCorrect && !lastAnswerWrong) return BuddyMood.happy;
    if (lastAnswerWrong) return BuddyMood.sad;
    return BuddyMood.defaultMood;
  }

  void _loadQuizFromJson() {
    const Map<String, dynamic> quizJson = {
      "question": "What colour was Pip the Robot's lost gear?",
      "options": ["Red", "Green", "Blue", "Yellow"],
      "answer": "Blue"
    };
    question = quizJson['question'] as String;
    options = List<String>.from(quizJson['options'] as List);
    correctAnswer = quizJson['answer'] as String;
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-IN');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);

    _tts.setStartHandler(() {
      isPlaying = true;
      notifyListeners();
    });

    _tts.setCompletionHandler(() {
      isPlaying = false;
      showQuiz = true;
      notifyListeners();
    });

    _tts.setErrorHandler((msg) {
      isPlaying = false;
      hasError = true;
      errorMessage = msg;
      notifyListeners();
    });
  }

  Future<void> playStory() async {
    hasError = false;
    errorMessage = null;
    showQuiz = false;
    isCorrect = false;
    celebrate = false;
    selectedOption = null;
    shouldShake = false;
    lastAnswerWrong = false;
    isPreparingAudio = true;
    notifyListeners();

    try {
      await _tts.stop();
      await _audioPlayer.stop(); // stop any congrats/buzz still playing
      await _tts.speak(storyText);
    } catch (e) {
      hasError = true;
      errorMessage =
      'Oops! I could not read the story. Please check and try again.';
      notifyListeners();
    } finally {
      isPreparingAudio = false;
      notifyListeners();
    }
  }

  Future<void> _playCongrats() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(
        AssetSource('audio/congrats.mp3'),
      );
    } catch (e) {
      debugPrint('Audio play error: $e');
    }
  }

  Future<void> _playBuzz() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(
        AssetSource('audio/buzz.mp3'),
      );
    } catch (e) {
      debugPrint('Buzz play error: $e');
    }
  }

  Future<void> onOptionSelected(String option) async {
    // If congrats is playing and user taps another option, we want:
    // - wrong -> buzz replaces congrats
    // - right -> congrats plays again
    // So we DO NOT early-return here; we let logic run again.

    selectedOption = option;

    if (option == correctAnswer) {
      isCorrect = true;
      lastAnswerWrong = false;
      celebrate = true;
      shouldShake = false;
      confettiController.play();
      await _playCongrats();
    } else {
      isCorrect = false;
      lastAnswerWrong = true;
      celebrate = false;
      shouldShake = true;
      HapticFeedback.mediumImpact();
      await _playBuzz();
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 300));
      shouldShake = false;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    confettiController.dispose();
    _tts.stop();
    _audioPlayer.dispose();
    super.dispose();
  }
}

class StoryBuddyScreen extends StatelessWidget {
  const StoryBuddyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StoryQuizViewModel>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF3C4), Color(0xFFBDE0FE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  ' AI Story Buddy',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: BuddyWidget(mood: vm.buddyMood),
                ),
              ),
              if (vm.isPlaying || vm.showQuiz)
                StoryCard(text: vm.storyText),
              const SizedBox(height: 16),
              ReadButton(vm: vm),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: vm.showQuiz
                    ? QuizWidget(vm: vm)
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class BuddyWidget extends StatefulWidget {
  final BuddyMood mood;
  const BuddyWidget({super.key, required this.mood});

  @override
  State<BuddyWidget> createState() => _BuddyWidgetState();
}

class _BuddyWidgetState extends State<BuddyWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant BuddyWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String lottiePath;
    switch (widget.mood) {
      case BuddyMood.defaultMood:
        lottiePath = 'assets/animation/default.json';
        break;
      case BuddyMood.reading:
        lottiePath = 'assets/animation/listen.json';
        break;
      case BuddyMood.happy:
        lottiePath = 'assets/animation/happy.json';
        break;
      case BuddyMood.sad:
        lottiePath = 'assets/animation/sad.json';
        break;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: CircleAvatar(
          radius: 80,
          backgroundColor: Colors.white,
          child: Lottie.asset(
            lottiePath,
            fit: BoxFit.contain,
            repeat: true,
          ),
        ),
      ),
    );
  }
}
class StatusCard extends StatelessWidget {
  final StoryQuizViewModel vm;
  const StatusCard({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    String text;
    if (vm.hasError) {
      text = vm.errorMessage ?? 'Something went wrong. Try again!';
    } else if (vm.isPreparingAudio) {
      text = 'Getting Pip\'s story ready...';
    } else if (vm.isPlaying) {
      text = 'Listening time! Pip is telling the story...';
    } else {
      text = 'Tap the button to hear Pip\'s story.';
    }

    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

class StoryCard extends StatelessWidget {
  final String text;
  const StoryCard({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.white.withOpacity(0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class ReadButton extends StatelessWidget {
  final StoryQuizViewModel vm;
  const ReadButton({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: vm.isPlaying ? null : () => vm.playStory(),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        backgroundColor: Colors.deepOrangeAccent,
      ),
      icon: const Icon(Icons.volume_up),
      label: Text(vm.isPlaying ? 'Reading...' : 'Read Me a Story'),
    );
  }
}

class QuizWidget extends StatelessWidget {
  final StoryQuizViewModel vm;
  const QuizWidget({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    final quizCard = Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              vm.question,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Column(
              children: vm.options.map((opt) {
                final isSelected = vm.selectedOption == opt;
                final isCorrect = vm.isCorrect && opt == vm.correctAnswer;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ElevatedButton(
                    onPressed: () {
                      debugPrint('Tapped option: $opt');
                      vm.onOptionSelected(opt);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCorrect
                          ? Colors.green
                          : isSelected
                          ? Colors.orange
                          : Colors.white,
                      foregroundColor:
                      isSelected || isCorrect ? Colors.white : Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(opt),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );

    final content = vm.shouldShake ? ShakeWidget(child: quizCard) : quizCard;

    return Stack(
      alignment: Alignment.center,
      children: [
        content,
        if (vm.celebrate)
          ConfettiWidget(
            confettiController: vm.confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 20,
            maxBlastForce: 20,
            minBlastForce: 5,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.orange,
              Colors.purple,
            ],
          ),
      ],
    );
  }
}

class ShakeWidget extends StatefulWidget {
  final Widget child;
  const ShakeWidget({super.key, required this.child});

  @override
  State<ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..forward();

    _offsetAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 12), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 12, end: -12), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -12, end: 0), weight: 1),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offsetAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_offsetAnimation.value, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}