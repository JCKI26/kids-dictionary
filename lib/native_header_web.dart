import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;

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

NativeHeaderCallbacks? _callbacks;

List<String> _words = const [];

String? _iconColor;
String? _backgroundColor;

void setNativeHeaderCallbacks(NativeHeaderCallbacks? callbacks) {
  _callbacks = callbacks;
  _words = callbacks?.words ?? const [];
}

void setNativeHeaderIconColor(String? color) {
  _iconColor = color;
}

void setNativeHeaderBackgroundColor(String? color) {
  _backgroundColor = color;
}

void registerNativeHeaderFactory() {
  ui_web.platformViewRegistry.registerViewFactory('native-header', (int viewId) {
    final root = web.HTMLDivElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.paddingTop = 'env(safe-area-inset-top)'
      ..style.boxSizing = 'border-box'
      ..style.display = 'flex'
      ..style.flexDirection = 'column'
      ..style.backgroundColor = _backgroundColor ?? '#9EF2E4'
      ..style.color = '#005048'
      ..style.fontFamily = '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';

    final titleRow = web.HTMLDivElement()
      ..style.height = '40px'
      ..style.display = 'flex'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'center'
      ..style.fontSize = '20px'
      ..style.fontWeight = 'bold'
      ..style.letterSpacing = '0.5px'
      ..style.flexShrink = '0'
      ..textContent = 'Kids Dictionary';
    root.appendChild(titleRow);

    final buttonRow = web.HTMLDivElement()
      ..style.height = '56px'
      ..style.display = 'flex'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'space-between'
      ..style.padding = '0'
      ..style.gap = '0'
      ..style.flexShrink = '0';
    root.appendChild(buttonRow);

    final leftGroup = web.HTMLDivElement()
      ..style.display = 'flex'
      ..style.alignItems = 'center'
      ..style.gap = '0';
    buttonRow.appendChild(leftGroup);

    final homeBtn = _iconButton(_svgIcon(_homeIconPath), 'Home / 首页');
    homeBtn.addEventListener('click', (() => _callbacks?.onHome()).toJS);
    homeBtn.addEventListener('touchstart', (() => _callbacks?.onHome()).toJS);
    leftGroup.appendChild(homeBtn);

    final settingsBtn = _iconButton(_svgIcon(_settingsIconPath), 'Settings / 选项');
    settingsBtn.addEventListener('click', (() => _callbacks?.onSettings()).toJS);
    settingsBtn.addEventListener('touchstart', (() => _callbacks?.onSettings()).toJS);
    leftGroup.appendChild(settingsBtn);

    final searchBox = web.HTMLDivElement()
      ..style.flex = '1'
      ..style.minWidth = '0'
      ..style.height = '40px'
      ..style.display = 'flex'
      ..style.alignItems = 'center'
      ..style.gap = '0'
      ..style.backgroundColor = '#FFFFFF'
      ..style.borderRadius = '8px'
      ..style.padding = '0 12px'
      ..style.marginRight = '12px'
      ..style.position = 'relative';

    final searchIcon = _svgIcon(_searchIconPath, fill: _iconColor ?? '#005048');
    searchIcon.setAttribute('width', '24');
    searchIcon.setAttribute('height', '24');

    final searchInput = web.HTMLInputElement()
      ..type = 'search'
      ..placeholder = 'Search / 搜尋'
      ..style.flex = '1'
      ..style.height = '100%'
      ..style.border = 'none'
      ..style.backgroundColor = 'transparent'
      ..style.fontSize = '18px'
      ..style.color = '#005048'
      ..style.outline = 'none';

    final dropdown = web.HTMLDivElement()
      ..style.position = 'absolute'
      ..style.top = 'calc(100% + 4px)'
      ..style.left = '0'
      ..style.right = '0'
      ..style.maxHeight = '250px'
      ..style.overflowY = 'auto'
      ..style.backgroundColor = '#FFFFFF'
      ..style.borderRadius = '8px'
      ..style.boxShadow = '0 4px 12px rgba(0,0,0,0.15)'
      ..style.zIndex = '1000'
      ..style.display = 'none';

    void updateSuggestions() {
      final query = searchInput.value.trim().toLowerCase();
      dropdown.textContent = '';
      if (query.isEmpty) {
        dropdown.style.display = 'none';
        return;
      }
      final matches = _words
          .where((w) => w.toLowerCase().startsWith(query))
          .take(10)
          .toList();
      if (matches.isEmpty) {
        dropdown.style.display = 'none';
        return;
      }
      for (final match in matches) {
        final item = web.HTMLDivElement()
          ..style.padding = '10px 12px'
          ..style.cursor = 'pointer'
          ..style.fontSize = '16px'
          ..style.color = '#005048'
          ..style.borderBottom = '1px solid #EEEEEE'
          ..style.userSelect = 'none'
          ..textContent = match;
        item.addEventListener('click', (() {
          searchInput.value = match;
          dropdown.style.display = 'none';
          _callbacks?.onSearchSubmitted(match);
        }).toJS);
        item.addEventListener('touchstart', (() {
          searchInput.value = match;
          dropdown.style.display = 'none';
          _callbacks?.onSearchSubmitted(match);
        }).toJS);
        dropdown.appendChild(item);
      }
      dropdown.style.display = 'block';
    }

    searchInput.addEventListener('input', (() => updateSuggestions()).toJS);
    searchInput.addEventListener('focus', (() => updateSuggestions()).toJS);
    searchInput.addEventListener(
      'keydown',
      ((web.Event event) {
        final keyboardEvent = event as web.KeyboardEvent;
        if (keyboardEvent.key == 'Escape') {
          dropdown.style.display = 'none';
        }
      }).toJS,
    );
    searchInput.addEventListener(
      'blur',
      (() {
        Future.delayed(const Duration(milliseconds: 150), () {
          dropdown.style.display = 'none';
        });
      }).toJS,
    );

    searchBox.appendChild(searchIcon);
    searchBox.appendChild(searchInput);
    searchBox.appendChild(dropdown);

    final searchForm = web.HTMLFormElement()
      ..style.flex = '1'
      ..style.minWidth = '0'
      ..style.display = 'flex'
      ..style.alignItems = 'center'
      ..style.margin = '0'
      ..style.padding = '0'
      ..action = 'javascript:void(0)';
    searchForm.appendChild(searchBox);
    searchForm.addEventListener(
      'submit',
      ((web.Event event) {
        event.preventDefault();
        dropdown.style.display = 'none';
        _callbacks?.onSearchSubmitted(searchInput.value);
      }).toJS,
    );
    buttonRow.appendChild(searchForm);

    final rightGroup = web.HTMLDivElement()
      ..style.display = 'flex'
      ..style.alignItems = 'center'
      ..style.gap = '0';
    buttonRow.appendChild(rightGroup);

    final learnedBtn = _iconButton(_svgIcon(_checkCircleIconPath), 'Learnt words / 已学会单词');
    learnedBtn.addEventListener('click', (() => _callbacks?.onLearned()).toJS);
    learnedBtn.addEventListener('touchstart', (() => _callbacks?.onLearned()).toJS);
    rightGroup.appendChild(learnedBtn);

    final favoritesBtn = _iconButton(_svgIcon(_starBorderIconPath), 'Favourite words / 收藏单词');
    favoritesBtn.addEventListener('click', (() => _callbacks?.onFavorites()).toJS);
    favoritesBtn.addEventListener('touchstart', (() => _callbacks?.onFavorites()).toJS);
    rightGroup.appendChild(favoritesBtn);

    return root;
  });
}

web.HTMLButtonElement _iconButton(web.SVGSVGElement icon, String tooltip) {
  final btn = web.HTMLButtonElement()
    ..style.width = '48px'
    ..style.height = '48px'
    ..style.border = 'none'
    ..style.borderRadius = '8px'
    ..style.backgroundColor = 'transparent'
    ..style.display = 'flex'
    ..style.alignItems = 'center'
    ..style.justifyContent = 'center'
    ..style.cursor = 'pointer'
    ..title = tooltip;
  btn.appendChild(icon);
  return btn;
}

web.SVGSVGElement _svgIcon(String pathD, {String? fill}) {
  final svg = web.document.createElementNS('http://www.w3.org/2000/svg', 'svg') as web.SVGSVGElement;
  svg.setAttribute('viewBox', '0 0 24 24');
  svg.setAttribute('width', '24');
  svg.setAttribute('height', '24');
  svg.setAttribute('fill', fill ?? _iconColor ?? '#005048');
  svg.style.pointerEvents = 'none';

  final path = web.document.createElementNS('http://www.w3.org/2000/svg', 'path') as web.SVGPathElement;
  path.setAttribute('d', pathD);
  svg.appendChild(path);
  return svg;
}

const _homeIconPath = 'M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z';
const _settingsIconPath = 'M19.14 12.94c.04-.31.06-.63.06-.94 0-.31-.02-.63-.06-.94l2.03-1.58a.49.49 0 0 0 .12-.64l-1.92-3.32a.488.488 0 0 0-.59-.22l-2.39.96c-.54-.4-1.08-.73-1.69-.98l-.36-2.54a.484.484 0 0 0-.48-.41h-3.84a.484.484 0 0 0-.48.41l-.36 2.54c-.61.25-1.15.57-1.69.98l-2.39-.96a.488.488 0 0 0-.59.22L2.74 8.84a.49.49 0 0 0 .12.64l2.03 1.58c-.04.31-.06.63-.06.94s.02.63.06.94l-2.03 1.58a.49.49 0 0 0-.12.64l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.54.4 1.08.73 1.69.98l.36 2.54c.05.24.27.41.48.41h3.84c.24 0 .44-.17.48-.41l.36-2.54c.61-.25 1.15-.57 1.69-.98l2.39.96c.22.08.47 0 .59-.22l1.92-3.32a.49.49 0 0 0-.12-.64l-2.03-1.58zM12 15.6A3.6 3.6 0 1 1 12 8.4a3.6 3.6 0 0 1 0 7.2z';
const _checkCircleIconPath = 'M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm3.88-11.71L10 14.17l-1.88-1.88a.996.996 0 1 0-1.41 1.41L10 17l6.71-6.71a.996.996 0 0 0-1.41-1.41z';
const _starBorderIconPath = 'M22 9.24l-7.19-.62L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21 12 17.27 18.18 21l-1.63-7.03L22 9.24zM12 15.4l-3.76 2.27 1-4.28-3.32-2.88 4.38-.38L12 6.1l1.71 4.03 4.38.38-3.32 2.88 1 4.28L12 15.4z';

const _searchIconPath = 'M15.5 14h-.79l-.28-.27A6.471 6.471 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z';

class NativeHeader extends StatelessWidget {
  final NativeHeaderCallbacks callbacks;

  const NativeHeader({super.key, required this.callbacks});

  @override
  Widget build(BuildContext context) {
    setNativeHeaderCallbacks(callbacks);
    final colorScheme = Theme.of(context).colorScheme;
    final onSurfaceVariant = _colorToHex(colorScheme.onSurfaceVariant);
    final primaryContainer = _colorToHex(colorScheme.primaryContainer);
    setNativeHeaderIconColor(onSurfaceVariant);
    setNativeHeaderBackgroundColor(primaryContainer);
    final height = MediaQuery.of(context).padding.top + 96.0;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: const HtmlElementView(viewType: 'native-header'),
    );
  }
}

String _colorToHex(Color color) {
  final r = (color.r * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  final g = (color.g * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  final b = (color.b * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#$r$g$b';
}
