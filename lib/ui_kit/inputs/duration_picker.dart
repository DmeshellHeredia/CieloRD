import 'package:flutter/material.dart';

import '../../design/theme/cielo_colors.dart';
import '../../design/tokens/cielo_tokens.dart';
import '../../design/tokens/cielo_typography.dart';
import '../../l10n/cielo_format.dart';
import '../../l10n/cielo_strings.dart';
import 'cielo_choice_chip.dart';

/// Selector de duración opcional.
///
/// Ofrece valores rápidos y "Otra" para ajustar minutos y segundos con
/// botones de ±. Es un componente controlado: [value] viene del padre y cada
/// cambio se notifica con [onChanged]; `null` significa "sin duración".
class DurationPicker extends StatefulWidget {
  const DurationPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.presets = defaultPresets,
    this.maxMinutes = 999,
  });

  final Duration? value;
  final ValueChanged<Duration?> onChanged;
  final List<Duration> presets;
  final int maxMinutes;

  static const List<Duration> defaultPresets = <Duration>[
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(hours: 1),
  ];

  @override
  State<DurationPicker> createState() => _DurationPickerState();
}

class _DurationPickerState extends State<DurationPicker> {
  bool _customOpen = false;

  bool get _isPreset => widget.value != null && widget.presets.contains(widget.value);
  bool get _showCustom => _customOpen || (widget.value != null && !_isPreset);

  void _set(Duration? value) {
    if (value == null) {
      widget.onChanged(null);
      return;
    }
    final int max = widget.maxMinutes * 60 + 59;
    widget.onChanged(Duration(seconds: value.inSeconds.clamp(0, max)));
  }

  @override
  Widget build(BuildContext context) {
    final Duration? value = widget.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Wrap(
          spacing: CieloSpace.sm,
          runSpacing: CieloSpace.sm,
          children: <Widget>[
            for (final Duration preset in widget.presets)
              CieloChoiceChip(
                label: CieloFormat.duration(preset),
                semanticLabel: CieloFormat.durationSpoken(preset),
                selected: !_showCustom && value == preset,
                onSelected: (bool selected) {
                  setState(() => _customOpen = false);
                  _set(selected ? preset : null);
                },
              ),
            CieloChoiceChip(
              label: CieloStrings.durationOther,
              selected: _showCustom,
              leading: const Icon(Icons.tune_rounded),
              onSelected: (bool selected) {
                setState(() => _customOpen = selected);
                if (selected && value == null) _set(const Duration(minutes: 1));
                if (!selected) _set(null);
              },
            ),
          ],
        ),
        if (_showCustom) ...<Widget>[
          const SizedBox(height: CieloSpace.md),
          _Stepper(
            label: CieloStrings.durationMinutes,
            value: (value ?? Duration.zero).inMinutes,
            onChanged: (int minutes) =>
                _set(Duration(minutes: minutes, seconds: (value ?? Duration.zero).inSeconds % 60)),
            min: 0,
            max: widget.maxMinutes,
            step: 1,
          ),
          const SizedBox(height: CieloSpace.sm),
          _Stepper(
            label: CieloStrings.durationSeconds,
            value: (value ?? Duration.zero).inSeconds % 60,
            onChanged: (int seconds) =>
                _set(Duration(minutes: (value ?? Duration.zero).inMinutes, seconds: seconds)),
            min: 0,
            max: 55,
            step: 5,
          ),
        ],
        if (value != null) ...<Widget>[
          const SizedBox(height: CieloSpace.sm),
          TextButton.icon(
            onPressed: () {
              setState(() => _customOpen = false);
              _set(null);
            },
            icon: const Icon(Icons.close_rounded),
            label: const Text(CieloStrings.durationRemove),
          ),
        ],
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    required this.step,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final String unit = label.toLowerCase();
    return Row(
      children: <Widget>[
        Expanded(child: Text(label, style: text.bodyLarge?.copyWith(color: c.textSecondary))),
        IconButton.filledTonal(
          tooltip: CieloStrings.durationDecrease(unit),
          onPressed: value > min ? () => onChanged((value - step).clamp(min, max)) : null,
          icon: const Icon(Icons.remove_rounded),
        ),
        Semantics(
          liveRegion: true,
          label: '$label: $value',
          excludeSemantics: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 64),
            child: Text(
              value.toString().padLeft(2, '0'),
              textAlign: TextAlign.center,
              style: CieloTypography.tabular(text.titleLarge ?? const TextStyle()),
            ),
          ),
        ),
        IconButton.filledTonal(
          tooltip: CieloStrings.durationIncrease(unit),
          onPressed: value < max ? () => onChanged((value + step).clamp(min, max)) : null,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}
