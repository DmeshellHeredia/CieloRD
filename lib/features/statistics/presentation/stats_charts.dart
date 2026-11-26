import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../../l10n/cielo_strings.dart';

/// Una fila de [RankedBars].
@immutable
class RankedBar {
  const RankedBar({required this.label, required this.count, this.leading});
  final String label;
  final int count;
  final Widget? leading;
}

/// Barras horizontales con nombre y cifra escritos: la magnitud se lee por
/// longitud y número; la identidad, por texto y glifo. Nunca solo por color.
class RankedBars extends StatelessWidget {
  const RankedBars({super.key, required this.bars});

  final List<RankedBar> bars;

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final int max = bars.fold(1, (int m, RankedBar b) => math.max(m, b.count));
    return Column(
      children: <Widget>[
        for (final RankedBar bar in bars)
          Semantics(
            container: true,
            label: '${bar.label}: ${CieloStrings.observationsCount(bar.count)}',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.only(bottom: CieloSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      if (bar.leading != null) ...<Widget>[
                        bar.leading!,
                        const SizedBox(width: CieloSpace.sm),
                      ],
                      Expanded(
                        child: Text(
                          bar.label,
                          style: text.bodyLarge?.copyWith(color: c.textPrimary),
                        ),
                      ),
                      const SizedBox(width: CieloSpace.md),
                      Text(
                        '${bar.count}',
                        style: CieloTypography.tabular(
                          text.titleMedium ?? const TextStyle(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CieloSpace.xs),
                  SizedBox(
                    height: 8,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _BarPainter(
                        fraction: bar.count / max,
                        fill: c.primary,
                        track: c.surface3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _BarPainter extends CustomPainter {
  const _BarPainter({
    required this.fraction,
    required this.fill,
    required this.track,
  });
  final double fraction;
  final Color fill;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const Radius end = Radius.circular(4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, end),
      Paint()..color = track,
    );
    if (fraction <= 0) return;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(0, 0, math.max(4, size.width * fraction), size.height),
        topRight: end,
        bottomRight: end,
        topLeft: end,
        bottomLeft: end,
      ),
      Paint()..color = fill,
    );
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.fraction != fraction || old.fill != fill || old.track != track;
}

/// Una columna de [ColumnChart].
@immutable
class ChartColumn {
  const ChartColumn({
    required this.axisLabel,
    required this.label,
    required this.count,
    this.showAxisLabel = true,
  });

  /// Texto corto bajo la columna.
  final String axisLabel;

  /// Nombre completo para la lectura y la tabla.
  final String label;
  final int count;
  final bool showAxisLabel;
}

/// Columnas en orden temporal. Al tocar una se lee su valor; el botón cambia a
/// tabla, que es la versión accesible con texto completo.
class ColumnChart extends StatefulWidget {
  const ColumnChart({super.key, required this.columns, required this.title});

  final List<ChartColumn> columns;
  final String title;

  @override
  State<ColumnChart> createState() => _ColumnChartState();
}

class _ColumnChartState extends State<ColumnChart> {
  int? _selected;
  bool _table = false;

  int get _peak {
    int best = 0;
    for (int i = 1; i < widget.columns.length; i++) {
      if (widget.columns[i].count > widget.columns[best].count) best = i;
    }
    return best;
  }

  void _select(Offset position, double width) {
    final int count = widget.columns.length;
    final int index = (position.dx / width * count).floor();
    setState(() => _selected = index.clamp(0, count - 1));
  }

  @override
  void didUpdateWidget(ColumnChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.columns.length != widget.columns.length) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final ChartColumn peak = widget.columns[_peak];
    final String peakText = CieloStrings.statsPeak(
      peak.label,
      CieloStrings.observationsCount(peak.count),
    );
    final int? selected = _selected;
    final String reading = selected == null
        ? peakText
        : '${widget.columns[selected].label}: '
              '${CieloStrings.observationsCount(widget.columns[selected].count)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_table)
          _ColumnTable(columns: widget.columns)
        else ...<Widget>[
          ExcludeSemantics(
            child: Text(
              reading,
              style: text.bodyMedium?.copyWith(color: c.textPrimary),
            ),
          ),
          const SizedBox(height: CieloSpace.sm),
          Semantics(
            container: true,
            image: true,
            label: '${widget.title}. $peakText',
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double width = constraints.maxWidth;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  onTapDown: (TapDownDetails d) =>
                      _select(d.localPosition, width),
                  onHorizontalDragUpdate: (DragUpdateDetails d) =>
                      _select(d.localPosition, width),
                  child: CustomPaint(
                    size: Size(width, 168),
                    painter: _ColumnPainter(
                      columns: widget.columns,
                      selected: selected,
                      bar: c.primary,
                      selectedBar: c.accent,
                      baseline: c.outlineStrong,
                      labelStyle: (text.labelSmall ?? const TextStyle())
                          .copyWith(color: c.textSecondary),
                      // Etiquetas de eje: el texto grande completo está en la
                      // tabla; aquí se limita para que no se solapen.
                      scaler: MediaQuery.textScalerOf(context)
                          .clamp(maxScaleFactor: 1.3),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => setState(() => _table = !_table),
            icon: Icon(
              _table ? Icons.bar_chart_rounded : Icons.table_rows_rounded,
            ),
            label: Text(
              _table
                  ? CieloStrings.statsShowChart
                  : CieloStrings.statsShowTable,
            ),
          ),
        ),
      ],
    );
  }
}

class _ColumnPainter extends CustomPainter {
  const _ColumnPainter({
    required this.columns,
    required this.selected,
    required this.bar,
    required this.selectedBar,
    required this.baseline,
    required this.labelStyle,
    required this.scaler,
  });

  final List<ChartColumn> columns;
  final int? selected;
  final Color bar;
  final Color selectedBar;
  final Color baseline;
  final TextStyle labelStyle;
  final TextScaler scaler;

  @override
  void paint(Canvas canvas, Size size) {
    final double labelHeight = scaler.scale(labelStyle.fontSize ?? 12) * 1.5;
    final double bottom = size.height - labelHeight;
    final double slot = size.width / columns.length;
    final double width = math.max(2, math.min(slot - 2, 24));
    final int max = columns.fold(
      1,
      (int m, ChartColumn col) => math.max(m, col.count),
    );
    for (int i = 0; i < columns.length; i++) {
      final double center = slot * (i + 0.5);
      final double height = (bottom - 4) * columns[i].count / max;
      if (height > 0) {
        final Rect rect = Rect.fromLTRB(
          center - width / 2,
          bottom - math.max(3, height),
          center + width / 2,
          bottom,
        );
        final RRect shape = RRect.fromRectAndCorners(
          rect,
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        );
        canvas.drawRRect(
          shape,
          Paint()..color = i == selected ? selectedBar : bar,
        );
      }
      if (i == selected) {
        // La selección se marca también con forma, no solo con color.
        canvas.drawPath(
          Path()
            ..moveTo(center - 5, bottom + 8)
            ..lineTo(center + 5, bottom + 8)
            ..lineTo(center, bottom + 2)
            ..close(),
          Paint()..color = selectedBar,
        );
      }
      if (columns[i].showAxisLabel && i != selected) {
        final TextPainter label = TextPainter(
          text: TextSpan(text: columns[i].axisLabel, style: labelStyle),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
        )..layout();
        final double left = (center - label.width / 2).clamp(
          0,
          math.max(0, size.width - label.width),
        );
        label.paint(canvas, Offset(left, bottom + 4));
        label.dispose();
      }
    }
    canvas.drawLine(
      Offset(0, bottom),
      Offset(size.width, bottom),
      Paint()
        ..color = baseline
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_ColumnPainter old) =>
      old.columns != columns ||
      old.selected != selected ||
      old.bar != bar ||
      old.selectedBar != selectedBar ||
      old.baseline != baseline ||
      old.labelStyle != labelStyle ||
      old.scaler != scaler;
}

class _ColumnTable extends StatelessWidget {
  const _ColumnTable({required this.columns});

  final List<ChartColumn> columns;

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      children: <Widget>[
        for (final ChartColumn column in columns)
          MergeSemantics(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: CieloSpace.sm),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.outline)),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      column.label,
                      style: text.bodyLarge?.copyWith(color: c.textPrimary),
                    ),
                  ),
                  const SizedBox(width: CieloSpace.md),
                  Text(
                    '${column.count}',
                    style: CieloTypography.tabular(
                      text.titleMedium ?? const TextStyle(),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
