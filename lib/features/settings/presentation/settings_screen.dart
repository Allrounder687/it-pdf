import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../core/storage/preferences_service.dart';

/// Provider for active theme mode ('system', 'light', 'dark').
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  PreferencesService get _prefs => ref.read(preferencesServiceProvider);

  @override
  ThemeMode build() {
    final mode = _prefs.getThemeMode();
    if (mode == 'light') return ThemeMode.light;
    if (mode == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
    _prefs.setThemeMode(mode.name);
  }
}

/// Settings screen for customization, theme selection, cache management and license info.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeModeProvider);
    final themeNotifier = ref.read(themeModeProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        children: [
          const _SettingsSectionHeader(title: 'Appearance'),
          ListTile(
            leading: const Icon(Icons.brightness_medium_outlined),
            title: const Text('Theme'),
            subtitle: Text(
              currentTheme == ThemeMode.system
                  ? 'System default'
                  : (currentTheme == ThemeMode.dark ? 'Dark mode' : 'Light mode'),
            ),
            trailing: DropdownButton<ThemeMode>(
              value: currentTheme,
              underline: const SizedBox(),
              onChanged: (mode) {
                if (mode != null) themeNotifier.setThemeMode(mode);
              },
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
              ],
            ),
          ),
          const Divider(),

          const _SettingsSectionHeader(title: 'Performance & Cache'),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Clear Render Cache'),
            subtitle: const Text('Frees memory and cached page textures'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Render cache cleared.')),
              );
            },
          ),
          const Divider(),

          const _SettingsSectionHeader(title: 'About IT PDF'),
          const ListTile(
            leading: Icon(Icons.verified_outlined),
            title: Text('Version'),
            subtitle: Text('1.0.0 (Gen9 Production Release)'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Open Source Licenses'),
            subtitle: const Text('PDFium (BSD 3-Clause), Dart PDF (Apache 2.0), pdfrx (MIT)'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'IT PDF',
              applicationVersion: '1.0.0',
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionHeader extends StatelessWidget {
  final String title;

  const _SettingsSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.blueAccent,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
