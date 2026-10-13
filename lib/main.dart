import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'home.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.init();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, systemNavigationBarColor: Colors.transparent));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const MyListApp());
  store.fetchPosters();
}

class MyListApp extends StatelessWidget {
  const MyListApp({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final skin = Skin.of(store.look, store.editorialDark);
          return MaterialApp(
            title: 'MyList',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(skin, Cat.anime.accent),
            themeAnimationDuration: const Duration(milliseconds: 450),
            themeAnimationCurve: easeOut,
            builder: (context, child) => Gate(
              child: Stack(fit: StackFit.expand, children: [
                ValueListenableBuilder<Color>(
                  valueListenable: glow,
                  builder: (_, c, _) => Backdrop(accent: c, imagePath: store.bgPath, dim: store.bgDim),
                ),
                child!,
              ]),
            ),
            home: const Home(),
          );
        },
      );
}

/// Locks the app behind device auth on launch and after 15s in background.
class Gate extends StatefulWidget {
  const Gate({super.key, required this.child});

  final Widget child;

  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> with WidgetsBindingObserver {
  final _auth = LocalAuthentication();
  bool _locked = store.lock;
  bool _busy = false;
  DateTime? _paused;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_locked) _unlock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) _paused = DateTime.now();
    if (s == AppLifecycleState.resumed && store.lock && _paused != null) {
      if (DateTime.now().difference(_paused!) > const Duration(seconds: 15)) {
        setState(() => _locked = true);
        _unlock();
      }
      _paused = null;
    }
  }

  Future<void> _unlock() async {
    if (_busy) return;
    _busy = true;
    try {
      if (await _auth.authenticate(localizedReason: 'Unlock MyList') && mounted) setState(() => _locked = false);
    } catch (_) {
      // no secure lock available any more -> don't lock the user out of their own list
      if (!await _auth.isDeviceSupported() && mounted) setState(() => _locked = false);
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        widget.child,
        IgnorePointer(
          ignoring: !_locked,
          child: AnimatedOpacity(
            opacity: _locked ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            curve: easeOut,
            child: _locked ? _LockScreen(onTap: _unlock) : const SizedBox.expand(),
          ),
        ),
      ]);
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.skin;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
      child: ColoredBox(
        color: s.bg.withValues(alpha: .82),
        child: Center(
          child: GestureDetector(
            onTap: onTap,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_rounded, size: 46, color: s.ink.withValues(alpha: .8)),
              const SizedBox(height: 16),
              Text('MyList', style: s.disp(30, w: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Tap to unlock', style: s.body(14, color: s.mute)),
            ]),
          ),
        ),
      ),
    );
  }
}
