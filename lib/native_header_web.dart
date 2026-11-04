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

void setNativeHeaderCallbacks(NativeHeaderCallbacks? callbacks) {
  _callbacks = callbacks;
  _words = callbacks?.words ?? const [];
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
      ..style.backgroundColor = '#9EF2E4'
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
      ..style.padding = '0 12px'
      ..style.gap = '8px'
      ..style.flexShrink = '0';
    root.appendChild(buttonRow);

    final leftGroup = web.HTMLDivElement()
      ..style.display = 'flex'
      ..style.alignItems = 'center'
      ..style.gap = '8px';
    buttonRow.appendChild(leftGroup);

    final homeBtn = _iconButton('🏠', 'Home / 首页');
    homeBtn.addEventListener('click', (() => _callbacks?.onHome()).toJS);
    leftGroup.appendChild(homeBtn);

    final settingsBtn = _iconButton('⚙️', 'Settings / 选项');
    settingsBtn.addEventListener('click', (() => _callbacks?.onSettings()).toJS);
    leftGroup.appendChild(settingsBtn);

    final searchForm = web.HTMLFormElement()
      ..style.flex = '1'
      ..style.minWidth = '0'
      ..style.display = 'flex'
      ..style.margin = '0'
      ..style.padding = '0'
      ..action = 'javascript:void(0)';

    final searchInput = web.HTMLInputElement()
      ..type = 'search'
      ..placeholder = 'Search / 搜尋'
      ..style.width = '100%'
      ..style.height = '40px'
      ..style.borderRadius = '8px'
      ..style.border = 'none'
      ..style.padding = '0 12px'
      ..style.fontSize = '16px'
      ..style.color = '#005048'
      ..style.backgroundColor = '#FFFFFF'
      ..style.outline = 'none';

    final dataListId = 'native-header-search-suggestions';
    searchInput.setAttribute('list', dataListId);

    final dataList = web.HTMLDataListElement()
      ..id = dataListId;
    for (final word in _words) {
      final option = web.HTMLOptionElement()..value = word;
      dataList.appendChild(option);
    }

    searchForm.appendChild(searchInput);
    searchForm.appendChild(dataList);
    searchForm.addEventListener(
      'submit',
      ((web.Event event) {
        event.preventDefault();
        _callbacks?.onSearchSubmitted(searchInput.value);
      }).toJS,
    );
    buttonRow.appendChild(searchForm);

    final rightGroup = web.HTMLDivElement()
      ..style.display = 'flex'
      ..style.alignItems = 'center'
      ..style.gap = '8px';
    buttonRow.appendChild(rightGroup);

    final learnedBtn = _iconButton('✅', 'Learnt words / 已学会单词');
    learnedBtn.addEventListener('click', (() => _callbacks?.onLearned()).toJS);
    rightGroup.appendChild(learnedBtn);

    final favoritesBtn = _iconButton('⭐', 'Favourite words / 收藏单词');
    favoritesBtn.addEventListener('click', (() => _callbacks?.onFavorites()).toJS);
    rightGroup.appendChild(favoritesBtn);

    return root;
  });
}

web.HTMLButtonElement _iconButton(String emoji, String tooltip) {
  return web.HTMLButtonElement()
    ..style.width = '40px'
    ..style.height = '40px'
    ..style.border = 'none'
    ..style.borderRadius = '8px'
    ..style.backgroundColor = 'transparent'
    ..style.fontSize = '22px'
    ..style.display = 'flex'
    ..style.alignItems = 'center'
    ..style.justifyContent = 'center'
    ..style.cursor = 'pointer'
    ..title = tooltip
    ..textContent = emoji;
}

class NativeHeader extends StatelessWidget {
  final NativeHeaderCallbacks callbacks;

  const NativeHeader({super.key, required this.callbacks});

  @override
  Widget build(BuildContext context) {
    setNativeHeaderCallbacks(callbacks);
    final height = MediaQuery.of(context).padding.top + 96.0;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: const HtmlElementView(viewType: 'native-header'),
    );
  }
}
