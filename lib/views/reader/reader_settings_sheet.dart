import 'package:flutter/material.dart';

import '../../models/app_settings.dart';
import 'reader_theme.dart';

Future<void> showReaderSettingsSheet({
  required BuildContext context,
  required AppSettings settings,
  required ValueChanged<AppSettings> onChanged,
  required VoidCallback onReset,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _ReaderSettingsSheet(
      initialSettings: settings,
      onChanged: onChanged,
      onReset: onReset,
    ),
  );
}

class _ReaderSettingsSheet extends StatefulWidget {
  const _ReaderSettingsSheet({
    required this.initialSettings,
    required this.onChanged,
    required this.onReset,
  });

  final AppSettings initialSettings;
  final ValueChanged<AppSettings> onChanged;
  final VoidCallback onReset;

  @override
  State<_ReaderSettingsSheet> createState() => _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends State<_ReaderSettingsSheet> {
  late AppSettings _settings = widget.initialSettings;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _update(AppSettings value) {
    setState(() => _settings = value);
    widget.onChanged(value);
  }

  void _reset() {
    final defaults = AppSettings.defaults();
    setState(() => _settings = defaults);
    widget.onReset();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.resolve(_settings.readerTheme);
    final textStyle = readerTextStyle(_settings, palette);

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.88,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Reader settings',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey<String>('reader-reset-defaults'),
                  onPressed: _reset,
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('Reset'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
              children: <Widget>[
                _PreviewCard(settings: _settings),
                const SizedBox(height: 22),
                const _SectionLabel('Appearance'),
                _ChoiceRow<String>(
                  values: ReaderThemeValues.all,
                  selected: _settings.readerTheme,
                  labelFor: ReaderThemeValues.label,
                  keyFor: (value) => 'reader-theme-$value',
                  onSelected: (value) {
                    _update(_settings.copyWith(readerTheme: value));
                  },
                ),
                const SizedBox(height: 20),
                const _SectionLabel('Typography'),
                _ChoiceRow<String>(
                  values: const <String>[
                    ReaderFonts.lora,
                    ReaderFonts.nunito,
                    ReaderFonts.system,
                  ],
                  selected: _settings.fontFamily == 'default'
                      ? ReaderFonts.lora
                      : _settings.fontFamily,
                  labelFor: ReaderFonts.label,
                  keyFor: (value) => 'reader-font-$value',
                  onSelected: (value) {
                    _update(_settings.copyWith(fontFamily: value));
                  },
                ),
                const SizedBox(height: 10),
                _SliderRow(
                  sliderKey: const ValueKey<String>('reader-font-size'),
                  label: 'Font size',
                  valueLabel: '${_settings.fontSize.round()} pt',
                  value: _settings.fontSize.clamp(14, 30),
                  min: 14,
                  max: 30,
                  divisions: 32,
                  onChanged: (value) {
                    _update(_settings.copyWith(fontSize: value));
                  },
                ),
                _SliderRow(
                  sliderKey: const ValueKey<String>('reader-line-height'),
                  label: 'Line height',
                  valueLabel: _settings.lineHeight.toStringAsFixed(2),
                  value: _settings.lineHeight.clamp(1.2, 2.2),
                  min: 1.2,
                  max: 2.2,
                  divisions: 20,
                  onChanged: (value) {
                    _update(_settings.copyWith(lineHeight: value));
                  },
                ),
                _SliderRow(
                  sliderKey: const ValueKey<String>('reader-paragraph-spacing'),
                  label: 'Paragraph spacing',
                  valueLabel: '${_settings.readerParagraphSpacing.round()} pt',
                  value: _settings.readerParagraphSpacing.clamp(0, 28),
                  min: 0,
                  max: 28,
                  divisions: 28,
                  onChanged: (value) {
                    _update(_settings.copyWith(readerParagraphSpacing: value));
                  },
                ),
                _SliderRow(
                  sliderKey: const ValueKey<String>('reader-margin'),
                  label: 'Side margins',
                  valueLabel: '${_settings.pageMargin.round()} pt',
                  value: _settings.pageMargin.clamp(8, 40),
                  min: 8,
                  max: 40,
                  divisions: 32,
                  onChanged: (value) {
                    _update(_settings.copyWith(pageMargin: value));
                  },
                ),
                const SizedBox(height: 8),
                const _SectionLabel('Alignment'),
                _ChoiceRow<String>(
                  values: const <String>['left', 'justify'],
                  selected: _settings.readerTextAlign == 'justify'
                      ? 'justify'
                      : 'left',
                  labelFor: (value) =>
                      value == 'justify' ? 'Justified' : 'Left',
                  keyFor: (value) => 'reader-align-$value',
                  onSelected: (value) {
                    _update(_settings.copyWith(readerTextAlign: value));
                  },
                ),
                const SizedBox(height: 20),
                const _SectionLabel('Progress'),
                SwitchListTile.adaptive(
                  key: const ValueKey<String>('reader-show-progress'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show reading progress'),
                  subtitle: const Text(
                    'Display chapter and novel progress while reading.',
                  ),
                  value: _settings.readerShowProgress,
                  onChanged: (value) {
                    _update(_settings.copyWith(readerShowProgress: value));
                  },
                ),
                const SizedBox(height: 16),
                _ReadingSample(settings: _settings, textStyle: textStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.resolve(settings.readerTheme);
    return Container(
      key: const ValueKey<String>('reader-settings-preview'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        'The night was quiet, and the page was patient.',
        textAlign: readerTextAlign(settings),
        style: readerTextStyle(settings, palette).copyWith(fontSize: 18),
      ),
    );
  }
}

class _ReadingSample extends StatelessWidget {
  const _ReadingSample({required this.settings, required this.textStyle});

  final AppSettings settings;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.resolve(settings.readerTheme);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'A short sample',
            style: textStyle.copyWith(
              fontFamily: ReaderFonts.resolveFamily('lora'),
              fontSize: settings.fontSize * 1.15,
              fontWeight: FontWeight.w600,
              color: palette.text,
            ),
          ),
          SizedBox(height: settings.readerParagraphSpacing * 0.5),
          Text(
            'Every chapter should feel comfortable. Adjust the type, spacing, '
            'and paper colour until the words disappear and the story remains.',
            textAlign: readerTextAlign(settings),
            style: textStyle,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(letterSpacing: 1.3, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.keyFor,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelFor;
  final String Function(T value) keyFor;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final value in values)
          ChoiceChip(
            key: ValueKey<String>(keyFor(value)),
            label: Text(labelFor(value)),
            selected: value == selected,
            onSelected: (_) => onSelected(value),
          ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.sliderKey,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final Key sliderKey;
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(label)),
            Text(
              valueLabel,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ],
        ),
        Slider(
          key: sliderKey,
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: valueLabel,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
