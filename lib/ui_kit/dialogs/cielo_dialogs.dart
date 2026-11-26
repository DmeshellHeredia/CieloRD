import 'package:flutter/material.dart';

import '../../design/theme/cielo_colors.dart';
import '../../design/tokens/cielo_tokens.dart';
import '../../l10n/cielo_strings.dart';

/// Diálogo de confirmación simple. Devuelve `true` solo si se confirma.
Future<bool> showCieloConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = CieloStrings.cancel,
  bool destructive = false,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => CieloConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
    ),
  );
  return result ?? false;
}

class CieloConfirmDialog extends StatelessWidget {
  const CieloConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel = CieloStrings.cancel,
    this.destructive = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actionsOverflowDirection: VerticalDirection.up,
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(cancelLabel)),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: c.dangerFilledBackground, foregroundColor: c.onDangerFilled)
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

/// Confirmación para acciones irreversibles (Borrar todo).
///
/// Enumera exactamente qué se borrará y exige marcar una casilla antes de
/// habilitar el botón. No usa "mantener presionado", que es difícil con
/// TalkBack. Devuelve `true` solo si se confirma.
Future<bool> showCieloDangerConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  List<String> consequences = const <String>[],
  String? footnote,
  String acknowledgement = CieloStrings.eraseAllAcknowledge,
  String cancelLabel = CieloStrings.cancel,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => CieloDangerConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      consequences: consequences,
      footnote: footnote,
      acknowledgement: acknowledgement,
      cancelLabel: cancelLabel,
    ),
  );
  return result ?? false;
}

class CieloDangerConfirmDialog extends StatefulWidget {
  const CieloDangerConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.consequences = const <String>[],
    this.footnote,
    this.acknowledgement = CieloStrings.eraseAllAcknowledge,
    this.cancelLabel = CieloStrings.cancel,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final List<String> consequences;
  final String? footnote;
  final String acknowledgement;
  final String cancelLabel;

  @override
  State<CieloDangerConfirmDialog> createState() => _CieloDangerConfirmDialogState();
}

class _CieloDangerConfirmDialogState extends State<CieloDangerConfirmDialog> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return AlertDialog(
      icon: Icon(Icons.delete_forever_rounded, color: c.danger, size: CieloSize.iconLg),
      title: Text(widget.title, textAlign: TextAlign.center),
      scrollable: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(widget.message),
          if (widget.consequences.isNotEmpty) ...<Widget>[
            const SizedBox(height: CieloSpace.md),
            for (final String line in widget.consequences)
              Padding(
                padding: const EdgeInsets.only(bottom: CieloSpace.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Icon(Icons.remove_circle_outline_rounded, size: CieloSize.iconSm, color: c.danger),
                    ),
                    const SizedBox(width: CieloSpace.sm),
                    Expanded(child: Text(line, style: text.bodyLarge?.copyWith(color: c.textPrimary))),
                  ],
                ),
              ),
          ],
          if (widget.footnote != null) ...<Widget>[
            const SizedBox(height: CieloSpace.sm),
            Text(widget.footnote!, style: text.bodyMedium?.copyWith(color: c.textSecondary)),
          ],
          const SizedBox(height: CieloSpace.md),
          CheckboxListTile(
            value: _acknowledged,
            onChanged: (bool? v) => setState(() => _acknowledged = v ?? false),
            title: Text(widget.acknowledgement, style: text.bodyLarge?.copyWith(color: c.textPrimary)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actionsOverflowDirection: VerticalDirection.up,
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(widget.cancelLabel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: c.dangerFilledBackground, foregroundColor: c.onDangerFilled),
          onPressed: _acknowledged ? () => Navigator.of(context).pop(true) : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// Decisión al salir de un formulario con cambios sin guardar.
enum UnsavedChangesDecision { saveDraft, discard, keepEditing }

/// Hoja inferior al salir con cambios: acciones al alcance del pulgar.
/// Cerrar la hoja sin elegir equivale a [UnsavedChangesDecision.keepEditing].
Future<UnsavedChangesDecision> showUnsavedChangesSheet(BuildContext context) async {
  final UnsavedChangesDecision? result = await showModalBottomSheet<UnsavedChangesDecision>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (BuildContext context) => const UnsavedChangesSheet(),
  );
  return result ?? UnsavedChangesDecision.keepEditing;
}

class UnsavedChangesSheet extends StatelessWidget {
  const UnsavedChangesSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    void pop(UnsavedChangesDecision d) => Navigator.of(context).pop(d);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(CieloSpace.xl, 0, CieloSpace.xl, CieloSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Semantics(header: true, child: Text(CieloStrings.unsavedTitle, style: text.headlineSmall)),
          const SizedBox(height: CieloSpace.sm),
          Text(CieloStrings.unsavedMessage, style: text.bodyLarge?.copyWith(color: c.textSecondary)),
          const SizedBox(height: CieloSpace.xl),
          TextButton(
            onPressed: () => pop(UnsavedChangesDecision.keepEditing),
            child: const Text(CieloStrings.keepEditing),
          ),
          const SizedBox(height: CieloSpace.sm),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: c.danger,
              side: BorderSide(color: c.danger),
            ),
            onPressed: () => pop(UnsavedChangesDecision.discard),
            child: const Text(CieloStrings.discardChanges),
          ),
          const SizedBox(height: CieloSpace.sm),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(CieloSize.fieldTouch)),
            onPressed: () => pop(UnsavedChangesDecision.saveDraft),
            child: const Text(CieloStrings.saveDraft),
          ),
        ],
      ),
    );
  }
}
