import 'package:flutter/material.dart';

class NativeHeaderCallbacks {
  final VoidCallback onHome;
  final VoidCallback onSettings;
  final VoidCallback onLearned;
  final VoidCallback onFavorites;
  final ValueChanged<String> onSearchSubmitted;

  const NativeHeaderCallbacks({
    required this.onHome,
    required this.onSettings,
    required this.onLearned,
    required this.onFavorites,
    required this.onSearchSubmitted,
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
