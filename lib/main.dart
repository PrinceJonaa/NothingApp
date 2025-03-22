import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

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
  bool _canPlay = false;
  bool _silentMode = false;
  bool _showSettings = false;
  bool _showPulse = false;
  bool _appLocked = false;
  int _voidCounter = 0;

  final player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _initSettings();
  }

  Future<void> _initSettings() async {
    await _requestPermissions();

    final prefs = await SharedPreferences.getInstance();
    final lastOpened = prefs.getInt('lastOpened') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    _voidCounter = prefs.getInt('voidCounter') ?? 0;
    _silentMode = prefs.getBool('silentMode') ?? false;
    _appLocked = prefs.getBool('appLocked') ?? false;

    if (_appLocked) {
      setState(() => _canPlay = false);
      return;
    }

    await _preloadAudio();

    if (lastOpened == 0 || now - lastOpened >= 86400000) {
      prefs.setInt('lastOpened', now);
      _voidCounter++;
      prefs.setInt('voidCounter', _voidCounter);
      setState(() => _canPlay = true);
      _beginWhisper();
    }
  }

  Future<void> _preloadAudio() async {
    try {
      await player.setSourceAsset('whisper.mp3');
      await player.setSourceAsset('final_whisper.mp3');
      debugPrint("Audio preloaded successfully.");
    } catch (e) {
      debugPrint("Audio preload failed: \$e");
    }
  }

  Future<void> _requestPermissions() async {
    await Permission.storage.request();
  }

  Future<void> _beginWhisper() async {
    setState(() => _showPulse = true);
    await Future.delayed(const Duration(seconds: 10));
    setState(() => _showPulse = false);

    if (_voidCounter >= 33) {
      await player.play(AssetSource('final_whisper.mp3'));
      await Future.delayed(const Duration(seconds: 5));
      _showFinalMessage();
      return;
    }

    if (!_silentMode) {
      await player.play(AssetSource('whisper.mp3'));
      await Future.delayed(const Duration(seconds: 5));
    }

    _exitApp();
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
    prefs.setBool('silentMode', _silentMode);
  }

  void _launchMerch() async {
    final url = Uri.parse("https://yourmerchsite.com");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
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
              prefs.setBool('appLocked', true);
              Navigator.of(context).pop();
              setState(() => _canPlay = false);
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
          children: [
            Center(
              child: _showSettings
                  ? Column(
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
                    )
                  : const SizedBox.shrink(),
            ),
            if (_showPulse) const Center(child: AnimatedPulse()),
          ],
        ),
      ),
    );
  }
}

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
