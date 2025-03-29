import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

// Constants
const String prefLastOpened = 'lastOpened';
const String prefVoidCounter = 'voidCounter';
const String prefSilentMode = 'silentMode';
const String prefAppLocked = 'appLocked';
const String assetWhisper = 'assets/whisper.mp3';
const String assetFinalWhisper = 'assets/final_whisper.mp3';
const int visitThreshold = 33;
const int millisecondsInDay = 86400000;
const String merchUrl = "https://yourmerchsite.com"; // Placeholder

void main() {
  runApp(const NothingApp());
}

class NothingApp extends StatelessWidget {
  const NothingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: VoidScreen(),
    );
  }
}

class VoidScreen extends StatefulWidget {
  const VoidScreen({super.key});

  @override
  State<VoidScreen> createState() => _VoidScreenState();
}

class _VoidScreenState extends State<VoidScreen>
    with SingleTickerProviderStateMixin {
  bool _canPlay = false; // Determines if the whisper sequence should run
  bool _silentMode = false;
  bool _showSettings = false;
  bool _showPulse = false;
  bool _appLocked = false;
  int _voidCounter = 0;

  final player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _initializeVoidState();
  }

  @override
  void dispose() {
    player.dispose(); // Release audio player resources
    super.dispose();
  }

  Future<void> _initializeVoidState() async {
    // Storage permission is generally not needed for assets/shared_prefs
    // await _requestPermissions();
    await _loadPreferences();

    if (_appLocked) {
      setState(() => _canPlay = false); // Ensure UI reflects locked state
      return; // Don't proceed if locked
    }

    await _preloadAudio();
    await _checkDailyVisit();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _voidCounter = prefs.getInt(prefVoidCounter) ?? 0;
    _silentMode = prefs.getBool(prefSilentMode) ?? false;
    _appLocked = prefs.getBool(prefAppLocked) ?? false;
    // No need to call setState here as this runs before the first build
  }

  Future<void> _checkDailyVisit() async {
    final prefs = await SharedPreferences.getInstance();
    final lastOpened = prefs.getInt(prefLastOpened) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (lastOpened == 0 || now - lastOpened >= millisecondsInDay) {
      prefs.setInt(prefLastOpened, now);
      _voidCounter++;
      prefs.setInt(prefVoidCounter, _voidCounter);
      setState(() => _canPlay = true); // Enable the whisper sequence
      _beginWhisper(); // Start the sequence
    } else {
      setState(() => _canPlay = false); // Not time yet
    }
  }

  Future<void> _preloadAudio() async {
    try {
      // Preload both assets for potentially faster playback later
      await player.setSource(AssetSource(assetWhisper));
      await player.setSource(AssetSource(assetFinalWhisper));
      debugPrint("Audio preloaded successfully.");
    } catch (e) {
      debugPrint("Audio preload failed: $e");
      // Consider showing an error to the user or logging more formally
    }
  }

  // Removed _requestPermissions as it's likely unnecessary

  Future<void> _beginWhisper() async {
    if (!_canPlay || _appLocked) return; // Double check state

    setState(() => _showPulse = true);
    await Future.delayed(const Duration(seconds: 10)); // Pulse duration
    if (!mounted) return; // Check if widget is still in the tree
    setState(() => _showPulse = false);

    try {
      if (_voidCounter >= visitThreshold) {
        await player.play(AssetSource(assetFinalWhisper));
        await Future.delayed(const Duration(seconds: 5)); // Listen duration
        if (mounted) _showFinalMessage();
      } else {
        if (!_silentMode) {
          await player.play(AssetSource(assetWhisper));
          await Future.delayed(const Duration(seconds: 5)); // Listen duration
        }
        if (mounted) _exitApp();
      }
    } catch (e) {
      debugPrint("Error playing audio: $e");
      // Handle playback error, maybe show a message or just exit
      if (mounted) _exitApp();
    }
  }

  void _exitApp() {
    Navigator.of(context).push(_createFadeRoute(const ExitScreen()));
  }

  Route _createFadeRoute(Widget screen) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 800),
    );
  }

  void _toggleSilentMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _silentMode = !_silentMode);
    prefs.setBool(prefSilentMode, _silentMode);
  }

  void _launchMerch() async {
    final url = Uri.parse(merchUrl);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        debugPrint("Could not launch $url");
        // Optionally show a message to the user
      }
    } catch (e) {
      debugPrint("Error launching URL: $e");
      // Optionally show a message to the user
    }
  }

  void _onLongPress() {
    setState(() => _showSettings = !_showSettings);
  }

  void _showFinalMessage() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text(
          "Threshold Crossed",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Now live like you were never not here.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              prefs.setBool(prefAppLocked, true);
              Navigator.of(context).pop(); // Close the dialog
              setState(() {
                _appLocked = true; // Update state immediately
                _canPlay = false;
              });
            },
            child: const Text("Close", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_appLocked) {
      return const ExitScreen();
    }

    return GestureDetector(
      onLongPress: _onLongPress,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          alignment: Alignment.center,
          children: [
            // Show hidden menu if toggled
            if (_showSettings) _buildHiddenMenu(),
            // Show pulse animation if active
            if (_showPulse) const AnimatedPulse(),
            // If nothing else is showing, maybe a subtle background element?
            // For now, it's just black.
          ],
        ),
      ),
    );
  }

  // Extracted widget builder for the hidden menu
  Widget _buildHiddenMenu() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Hidden Menu",
            style: TextStyle(color: Colors.white, fontSize: 20)),
        const SizedBox(height: 20),
        Text("Void Visits: $_voidCounter",
            style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _toggleSilentMode,
          child: Text(
            _silentMode ? "Whisper: OFF" : "Whisper: ON",
            style: const TextStyle(color: Colors.white),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _launchMerch,
          child: const Text(
            "Merch from the Void",
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

// --- AnimatedPulse Widget (unchanged) ---
class AnimatedPulse extends StatefulWidget {
  const AnimatedPulse({super.key});

  @override
  _AnimatedPulseState createState() => _AnimatedPulseState();
}

class _AnimatedPulseState extends State<AnimatedPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _scaleAnimation = Tween(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.05),
        ),
      ),
    );
  }
}

class ExitScreen extends StatelessWidget {
  const ExitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              "You may leave now.",
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
            SizedBox(height: 10),
            Text(
              "But remember… the silence was never empty.",
              style: TextStyle(color: Colors.white38, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
