import 'package:flutter/material.dart';

import '../../../../app/contracts.dart';
import '../../../../design/design.dart';
import '../../../../l10n/cielo_strings.dart';
import '../../../../ui_kit/ui_kit.dart';
import 'diary_criteria.dart';

/// Abre el panel de filtros. Devuelve los criterios elegidos al tocar
/// "Ver resultados", o `null` si se cierra sin aplicar.
Future<DiaryCriteria?> showDiaryFilterSheet(BuildContext context, DiaryCriteria current) {
  return showModalBottomSheet<DiaryCriteria>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) => DiaryFilterSheet(initial: current),
  );
}

/// Contenido del panel. Los cambios son locales hasta aplicar, para que la
/// lista no salte con cada toque.
class DiaryFilterSheet extends StatefulWidget {
  const DiaryFilterSheet({super.key, required this.initial});

  final DiaryCriteria initial;

  @override
  State<DiaryFilterSheet> createState() => _DiaryFilterSheetState();
}

class _DiaryFilterSheetState extends State<DiaryFilterSheet> {
  late DiaryCriteria _draft = widget.initial;
  late final TextEditingController _place = TextEditingController(text: widget.initial.place);

  @override
  void dispose() {
    _place.dispose();
    super.dispose();
  }

  void _apply() => Navigator.of(context).pop(_draft.copyWith(place: _place.text.trim()));

  void _clearAll() {
    setState(() {
      _draft = DiaryCriteria(query: widget.initial.query);
      _place.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final CieloColors c = CieloColors.of(context);

    Widget group(String title, Widget child) => Padding(
          padding: const EdgeInsets.only(bottom: CieloSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(title, style: text.titleMedium?.copyWith(color: c.textSecondary)),
              ),
              const SizedBox(height: CieloSpace.sm),
              child,
            ],
          ),
        );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(CieloSpace.xl, 0, CieloSpace.xl, CieloSpace.lg),
            child: Semantics(header: true, child: Text(CieloStrings.filters, style: text.headlineSmall)),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: CieloSpace.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  group(
                    CieloStrings.statusLabel,
                    Wrap(
                      spacing: CieloSpace.sm,
                      runSpacing: CieloSpace.sm,
                      children: <Widget>[
                        for (final DiaryStatusView view in DiaryStatusView.values)
                          CieloChoiceChip(
                            label: view.label,
                            selected: _draft.statusView == view,
                            onSelected: (_) => setState(() => _draft = _draft.copyWith(statusView: view)),
                          ),
                      ],
                    ),
                  ),
                  group(
                    CieloStrings.dateLabel,
                    Wrap(
                      spacing: CieloSpace.sm,
                      runSpacing: CieloSpace.sm,
                      children: <Widget>[
                        for (final DiaryDateRange range in DiaryDateRange.values)
                          CieloChoiceChip(
                            label: range.label,
                            selected: _draft.dateRange == range,
                            onSelected: (_) => setState(() => _draft = _draft.copyWith(dateRange: range)),
                          ),
                      ],
                    ),
                  ),
                  group(
                    CieloStrings.categoryLabel,
                    Wrap(
                      spacing: CieloSpace.sm,
                      runSpacing: CieloSpace.sm,
                      children: <Widget>[
                        for (final ObservationCategory category in ObservationCategory.values)
                          CategoryChip(
                            category: CategoryVisual.fromCode(category.name),
                            multiSelect: false,
                            selected: _draft.category == category,
                            onSelected: (bool selected) => setState(
                              () => _draft = _draft.copyWith(category: () => selected ? category : null),
                            ),
                          ),
                      ],
                    ),
                  ),
                  group(
                    CieloStrings.placeLabel,
                    TextField(
                      controller: _place,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _apply(),
                      decoration: const InputDecoration(
                        hintText: CieloStrings.placeHint,
                        prefixIcon: Icon(Icons.place_rounded),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          CieloActionBar(
            primaryLabel: CieloStrings.showResults,
            onPrimary: _apply,
            secondaryLabel: CieloStrings.clearAll,
            onSecondary: _clearAll,
          ),
        ],
      ),
    );
  }
}
