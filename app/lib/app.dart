import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'controllers/audio_library_controller.dart';
import 'l10n/generated/app_localizations.dart';
import 'pages/audio_library_page.dart';
import 'services/audio_selection_service.dart';
import 'services/audio_image_store_service.dart';
import 'services/image_selection_service.dart';
import 'services/network_discovery_service.dart';
import 'services/soundpad_api_service.dart';
import 'theme/app_theme.dart';

class SoundpadDeckApp extends StatefulWidget {
  const SoundpadDeckApp({super.key, this.enableAutoRefresh = true});

  final bool enableAutoRefresh;

  @override
  State<SoundpadDeckApp> createState() => _SoundpadDeckAppState();
}

class _SoundpadDeckAppState extends State<SoundpadDeckApp> {
  late final AudioLibraryController _controller;
  late final ValueNotifier<ThemeMode> _themeMode;

  @override
  void initState() {
    super.initState();

    final apiService = SoundpadApiService();
    _controller = AudioLibraryController(
      apiService: apiService,
      discoveryService: NetworkDiscoveryService(apiService),
      imageStoreService: const AudioImageStoreService(),
      audioSelectionService: const AudioSelectionService(),
      imageSelectionService: const ImageSelectionService(),
      enableAutoRefresh: widget.enableAutoRefresh,
    );
    _themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);
  }

  @override
  void dispose() {
    _themeMode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _toggleThemeMode() {
    _themeMode.value = _themeMode.value == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeMode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          home: AudioLibraryPage(
            controller: _controller,
            isDarkMode: themeMode == ThemeMode.dark,
            onToggleTheme: _toggleThemeMode,
          ),
        );
      },
    );
  }
}
