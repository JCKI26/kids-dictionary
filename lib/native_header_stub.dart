import 'package:flutter/material.dart';

class NativeHeaderCallbacks {
  final VoidCallback onHome;
  final VoidCallback onSettings;
  final VoidCallback onLearned;
  final VoidCallback onFavorites;
  final ValueChanged<String> onSearchSubmitted;
  final List<String> words;

  const NativeHeaderCallbacks({
    required this.onHome,
    required this.onSettings,
    required this.onLearned,
    required this.onFavorites,
    required this.onSearchSubmitted,
    required this.words,
  });
}

void registerNativeHeaderFactory() {}

void setNativeHeaderCallbacks(NativeHeaderCallbacks? callbacks) {}

class NativeHeader extends StatelessWidget {
  final NativeHeaderCallbacks callbacks;

  const NativeHeader({super.key, required this.callbacks});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
