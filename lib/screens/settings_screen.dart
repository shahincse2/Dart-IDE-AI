import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/themes.dart';

/// Section 41's Settings screen: theme, font size, word wrap, indent
/// size, auto save — all backed by [SettingsProvider], which has
/// persisted these since Phase 1. This screen is the first place
/// they're actually exposed to the user; Phase 1 only had the
/// plumbing.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Editor theme'),
          _EditorThemeGrid(settings: settings),
          const Divider(height: 1),
          const _SectionHeader('App theme'),
          _AppThemeModeSelector(settings: settings),
          const Divider(height: 1),
          const _SectionHeader('Editor'),
          _FontSizeRow(settings: settings),
          _IndentSizeRow(settings: settings),
          SwitchListTile(
            title: const Text('Word wrap'),
            subtitle: const Text('Off: long lines scroll sideways instead of wrapping'),
            value: settings.wordWrap,
            onChanged: (value) => settings.setWordWrap(value),
          ),
          const Divider(height: 1),
          const _SectionHeader('Files'),
          SwitchListTile(
            title: const Text('Auto save'),
            subtitle: const Text('Saves automatically shortly after you stop typing'),
            value: settings.autoSaveEnabled,
            onChanged: (value) => settings.setAutoSaveEnabled(value),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spaceMd,
        AppConstants.spaceMd,
        AppConstants.spaceMd,
        AppConstants.spaceSm,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _EditorThemeGrid extends StatelessWidget {
  final SettingsProvider settings;
  const _EditorThemeGrid({required this.settings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceMd),
      child: Wrap(
        spacing: AppConstants.spaceSm,
        runSpacing: AppConstants.spaceSm,
        children: EditorColorScheme.all.map((scheme) {
          final selected = scheme.name == settings.editorThemeName;
          return _ThemeSwatch(
            scheme: scheme,
            selected: selected,
            onTap: () => settings.setEditorThemeName(scheme.name),
          );
        }).toList(),
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  final EditorColorScheme scheme;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeSwatch({required this.scheme, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final borderColor =
        selected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 104,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: scheme.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    scheme.name,
                    style: TextStyle(
                      color: scheme.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded,
                      size: 14, color: Theme.of(context).colorScheme.primary),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'void main()',
              style: TextStyle(color: scheme.keyword, fontFamily: editorFontFamily, fontSize: 11),
            ),
            Text(
              "print('hi');",
              style: TextStyle(color: scheme.string, fontFamily: editorFontFamily, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppThemeModeSelector extends StatelessWidget {
  final SettingsProvider settings;
  const _AppThemeModeSelector({required this.settings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceMd),
      child: SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(
            value: ThemeMode.system,
            label: Text('System'),
            icon: Icon(Icons.brightness_auto_rounded),
          ),
          ButtonSegment(
            value: ThemeMode.light,
            label: Text('Light'),
            icon: Icon(Icons.light_mode_outlined),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            label: Text('Dark'),
            icon: Icon(Icons.dark_mode_outlined),
          ),
        ],
        selected: {settings.themeMode},
        onSelectionChanged: (selection) => settings.setThemeMode(selection.first),
      ),
    );
  }
}

class _FontSizeRow extends StatelessWidget {
  final SettingsProvider settings;
  const _FontSizeRow({required this.settings});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('Font size'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_rounded),
            onPressed: settings.editorFontSize > AppConstants.minFontSize
                ? () => settings.setEditorFontSize(settings.editorFontSize - 1)
                : null,
          ),
          SizedBox(
            width: 32,
            child: Text(
              '${settings.editorFontSize.round()}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: settings.editorFontSize < AppConstants.maxFontSize
                ? () => settings.setEditorFontSize(settings.editorFontSize + 1)
                : null,
          ),
        ],
      ),
    );
  }
}

class _IndentSizeRow extends StatelessWidget {
  final SettingsProvider settings;
  const _IndentSizeRow({required this.settings});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('Indent size'),
      trailing: SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 2, label: Text('2')),
          ButtonSegment(value: 4, label: Text('4')),
        ],
        selected: {settings.indentSize},
        onSelectionChanged: (selection) => settings.setIndentSize(selection.first),
      ),
    );
  }
}
