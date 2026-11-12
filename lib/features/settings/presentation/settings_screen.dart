import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/pdf_engine/pdf_thumbnail_cache.dart';
import '../../../core/providers.dart';
import '../../../core/storage/preferences_service.dart';

const String _appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '1.2.2+5',
);

/// Provider for active theme mode ('system', 'light', 'dark').
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

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
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
                  : (currentTheme == ThemeMode.dark
                        ? 'Dark mode'
                        : 'Light mode'),
            ),
            trailing: DropdownButton<ThemeMode>(
              value: currentTheme,
              underline: const SizedBox(),
              onChanged: (mode) {
                if (mode != null) themeNotifier.setThemeMode(mode);
              },
              items: const [
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text('System'),
                ),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
              ],
            ),
          ),
          const Divider(),

          const _SettingsSectionHeader(title: 'AI Document Assistant'),
          const AiSettingsSection(),
          const Divider(),

          const _SettingsSectionHeader(title: 'Performance & Cache'),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Clear Render Cache'),
            subtitle: const Text('Frees memory and cached page textures'),
            onTap: () {
              PdfThumbnailCache.instance.clear();
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
            subtitle: Text('$_appVersion (Production Release)'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Open Source Licenses'),
            subtitle: const Text(
              'PDFium (BSD 3-Clause), Dart PDF (Apache 2.0), pdfrx (MIT)',
            ),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'IT PDF',
              applicationVersion: _appVersion,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable AI Document Assistant settings card & configuration form.
class AiSettingsSection extends ConsumerStatefulWidget {
  const AiSettingsSection({super.key});

  @override
  ConsumerState<AiSettingsSection> createState() => _AiSettingsSectionState();
}

class _AiSettingsSectionState extends ConsumerState<AiSettingsSection> {
  late String _provider;
  late TextEditingController _apiKeyController;
  late TextEditingController _modelController;
  late TextEditingController _endpointController;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(preferencesServiceProvider);
    _provider = prefs.getAiProvider();
    _apiKeyController = TextEditingController(text: prefs.getAiApiKey());
    _modelController = TextEditingController(text: prefs.getAiModel());
    _endpointController = TextEditingController(
      text: prefs.getAiCustomEndpoint(),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelController.dispose();
    _endpointController.dispose();
    super.dispose();
  }

  String get _defaultModelHint {
    switch (_provider) {
      case 'gemini':
        return 'gemini-2.5-flash';
      case 'openai':
        return 'gpt-4o-mini';
      default:
        return 'Built-in offline grounded extractor';
    }
  }

  Future<void> _saveSettings() async {
    final prefs = ref.read(preferencesServiceProvider);
    await prefs.setAiProvider(_provider);
    await prefs.setAiApiKey(_apiKeyController.text);
    await prefs.setAiModel(_modelController.text);
    await prefs.setAiCustomEndpoint(_endpointController.text);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _provider == 'offline'
              ? 'AI Assistant set to Offline Grounded mode.'
              : 'AI Assistant settings saved ($_provider).',
        ),
      ),
    );
  }

  Future<void> _clearKey() async {
    final prefs = ref.read(preferencesServiceProvider);
    _apiKeyController.clear();
    await prefs.setAiApiKey('');
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('API key cleared.')));
  }

  @override
  Widget build(BuildContext context) {
    final isCloud = _provider != 'offline';
    final hasKey = _apiKeyController.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.withAlpha(55)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'AI Provider & API Credentials',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      isCloud
                          ? (hasKey ? 'Cloud Ready' : 'Key Required')
                          : 'Offline Mode',
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: isCloud
                        ? (hasKey
                              ? Colors.green.withAlpha(35)
                              : Colors.orange.withAlpha(35))
                        : Colors.blueAccent.withAlpha(30),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _provider,
                decoration: const InputDecoration(
                  labelText: 'AI Engine Provider',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'offline',
                    child: Text('Offline Grounded Engine (Built-in, No Key)'),
                  ),
                  DropdownMenuItem(
                    value: 'gemini',
                    child: Text('Google Gemini API'),
                  ),
                  DropdownMenuItem(
                    value: 'openai',
                    child: Text('OpenAI / Compatible API'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _provider = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKeyController,
                obscureText: _obscureApiKey,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'API Key',
                  hintText: _provider == 'gemini'
                      ? 'AIza...'
                      : 'sk-... (optional in Offline mode)',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: const Icon(Icons.key_outlined),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: _obscureApiKey ? 'Show key' : 'Hide key',
                        icon: Icon(
                          _obscureApiKey
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscureApiKey = !_obscureApiKey),
                      ),
                      if (hasKey)
                        IconButton(
                          tooltip: 'Clear API key',
                          icon: const Icon(Icons.clear),
                          onPressed: _clearKey,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _modelController,
                decoration: InputDecoration(
                  labelText: 'Model Name (optional override)',
                  hintText: _defaultModelHint,
                  border: const OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: const Icon(Icons.memory_outlined),
                ),
              ),
              if (_provider == 'openai') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _endpointController,
                  decoration: const InputDecoration(
                    labelText: 'Custom Base URL (optional)',
                    hintText: 'https://api.openai.com/v1/chat/completions',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Save AI Settings'),
                      onPressed: _saveSettings,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Keys are stored locally on your device. If a cloud request fails or no key is set, IT PDF automatically falls back to the offline grounded extractor.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens a quick modal dialog to configure AI provider & API credentials.
Future<void> showAiSettingsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('AI Assistant Settings'),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      content: const SizedBox(
        width: 460,
        child: SingleChildScrollView(child: AiSettingsSection()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
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
