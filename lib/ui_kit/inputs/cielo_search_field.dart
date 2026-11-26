import 'package:flutter/material.dart';

import '../../design/theme/cielo_colors.dart';
import '../../design/tokens/cielo_tokens.dart';
import '../../l10n/cielo_strings.dart';

/// Campo de búsqueda de 56 dp con botón para borrar.
///
/// Controlado por [value]: si el padre lo cambia (p. ej. "Quitar todo"), el
/// texto visible se sincroniza sin perder la posición del cursor del usuario.
class CieloSearchField extends StatefulWidget {
  const CieloSearchField({
    super.key,
    required this.value,
    required this.onChanged,
    this.onSubmitted,
    this.hint = CieloStrings.searchHint,
    this.label = CieloStrings.searchLabel,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final String hint;

  /// Nombre accesible del campo.
  final String label;

  @override
  State<CieloSearchField> createState() => _CieloSearchFieldState();
}

class _CieloSearchFieldState extends State<CieloSearchField> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(CieloSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    widget.onSubmitted?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(CieloRadius.badge),
      borderSide: BorderSide(color: c.outlineStrong),
    );
    return Semantics(
      label: widget.label,
      textField: true,
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        textInputAction: TextInputAction.search,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixIcon: Icon(Icons.search_rounded, color: c.textSecondary),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (BuildContext context, TextEditingValue value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: CieloStrings.clearSearch,
                    onPressed: _clear,
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
          filled: true,
          fillColor: c.surface1,
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(borderSide: BorderSide(color: c.primary, width: 2)),
          constraints: const BoxConstraints(minHeight: CieloSize.fieldTouch),
          contentPadding: const EdgeInsets.symmetric(horizontal: CieloSpace.lg, vertical: CieloSpace.md),
        ),
      ),
    );
  }
}
