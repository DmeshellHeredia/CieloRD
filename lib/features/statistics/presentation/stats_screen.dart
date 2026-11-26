import 'package:flutter/material.dart';

import '../../../app/contracts.dart';
import '../../../design/design.dart';
import '../../../l10n/cielo_format.dart';
import '../../../l10n/cielo_strings.dart';
import '../../../l10n/failure_messages.dart';
import '../../../ui_kit/ui_kit.dart';
import 'stats_charts.dart';

/// Estadísticas locales de las observaciones publicadas.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.stats, this.clock});

  final StatsService stats;
  final DateTime Function()? clock;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Result<ObservationStats>? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_result is Failure) setState(() => _result = null);
    final Result<ObservationStats> result = await widget.stats.summarize(
      ObservationFilter(status: ObservationStatus.published),
    );
    if (mounted) setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(CieloStrings.statsTitle)),
    body: switch (_result) {
      null => const Padding(
        padding: EdgeInsets.all(CieloSpace.gutter),
        child: CieloSkeletonList(count: 4),
      ),
      Failure<ObservationStats>(:final AppFailure failure) => CieloErrorState(
        message: FailureMessages.of(failure),
        onRetry: _load,
      ),
      Success<ObservationStats>(:final ObservationStats value)
          when value.total == 0 =>
        const CieloEmptyState(
          title: CieloStrings.statsEmptyTitle,
          message: CieloStrings.statsEmptyMessage,
          icon: Icons.insights_rounded,
        ),
      Success<ObservationStats>(:final ObservationStats value) =>
        RefreshIndicator(
          onRefresh: _load,
          child: _StatsBody(
            stats: value,
            now: (widget.clock ?? DateTime.now)(),
          ),
        ),
    },
  );
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.stats, required this.now});

  final ObservationStats stats;
  final DateTime now;

  List<ChartColumn> _months() {
    return <ChartColumn>[
      for (int back = 11; back >= 0; back--)
        () {
          final DateTime month = DateTime(now.year, now.month - back);
          final String label = CieloFormat.monthYear(month);
          return ChartColumn(
            axisLabel: label[0],
            label: label,
            count: stats.byLocalMonth[ObservationStats.monthKey(month)] ?? 0,
          );
        }(),
    ];
  }

  List<ChartColumn> _hours() => <ChartColumn>[
    for (int hour = 0; hour < 24; hour++)
      ChartColumn(
        axisLabel: '$hour',
        label: CieloFormat.time(DateTime(2000, 1, 1, hour)),
        count: stats.byLocalHour[hour] ?? 0,
        showAxisLabel: hour % 6 == 0,
      ),
  ];

  List<RankedBar> _categories(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    return <RankedBar>[
      for (final ObservationCategory category in ObservationCategory.values)
        () {
          final CategoryVisual visual = CategoryVisual.fromCode(category.name);
          return RankedBar(
            label: visual.label,
            count: stats.byCategory[category] ?? 0,
            leading: CieloGlyphIcon(visual.glyph, color: visual.tint(c)),
          );
        }(),
    ];
  }

  List<RankedBar> _provinces() {
    final List<MapEntry<String, int>> sorted = stats.byProvince.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) {
        final int byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return <RankedBar>[
      for (final MapEntry<String, int> e in sorted.take(10))
        RankedBar(label: e.key, count: e.value),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final TextStyle? secondary = text.bodyMedium?.copyWith(
      color: c.textSecondary,
    );
    final List<RankedBar> provinces = _provinces();
    final bool largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final Widget total = _Figure(
      label: CieloStrings.statsTotal,
      value: '${stats.total}',
    );
    final Widget month = _Figure(
      label: CieloStrings.statsThisMonth,
      value: '${stats.inMonthOf(now)}',
      detail: CieloFormat.monthYear(now),
    );
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        CieloSpace.gutter,
        CieloSpace.sm,
        CieloSpace.gutter,
        CieloSpace.xxl,
      ),
      children: <Widget>[
        if (largeText) ...<Widget>[
          total,
          const SizedBox(height: CieloSpace.md),
          month,
        ] else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: total),
                const SizedBox(width: CieloSpace.md),
                Expanded(child: month),
              ],
            ),
          ),
        const SizedBox(height: CieloSpace.md),
        _Figure(
          label: CieloStrings.statsDuration,
          value: stats.withKnownDuration == 0
              ? '—'
              : CieloFormat.duration(
                  Duration(seconds: stats.knownDurationSeconds),
                ),
          spokenValue: stats.withKnownDuration == 0
              ? ''
              : CieloFormat.durationSpoken(
                  Duration(seconds: stats.knownDurationSeconds),
                ),
          detail: stats.withKnownDuration == 0
              ? CieloStrings.statsDurationNone
              : CieloStrings.statsDurationFrom(stats.withKnownDuration),
        ),
        const SizedBox(height: CieloSpace.sm),
        Text(CieloStrings.statsDraftsExcluded, style: secondary),
        const CieloSectionHeader(title: CieloStrings.statsByCategory),
        RankedBars(bars: _categories(context)),
        const CieloSectionHeader(
          title: CieloStrings.statsByMonth,
          subtitle: CieloStrings.statsByMonthHint,
        ),
        ColumnChart(columns: _months(), title: CieloStrings.statsByMonth),
        const CieloSectionHeader(
          title: CieloStrings.statsByHour,
          subtitle: CieloStrings.statsByHourHint,
        ),
        ColumnChart(columns: _hours(), title: CieloStrings.statsByHour),
        const CieloSectionHeader(
          title: CieloStrings.statsProvinces,
          subtitle: CieloStrings.statsProvincesHint,
        ),
        if (provinces.isEmpty)
          Text(CieloStrings.statsNoProvinces, style: secondary)
        else
          RankedBars(bars: provinces),
        const CieloSectionHeader(
          title: CieloStrings.statsPlaces,
          subtitle: CieloStrings.statsPlacesHint,
        ),
        if (stats.byPlace.isEmpty)
          Text(CieloStrings.statsNoPlaces, style: secondary)
        else
          RankedBars(
            bars: <RankedBar>[
              for (final PlaceCount p in stats.byPlace)
                RankedBar(label: p.place, count: p.count),
            ],
          ),
      ],
    );
  }
}

/// Cifra destacada, sin gráfico.
class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    this.detail,
    this.spokenValue,
  });

  final String label;
  final String value;
  final String? detail;
  final String? spokenValue;

  @override
  Widget build(BuildContext context) {
    final CieloColors c = CieloColors.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    final TextStyle? secondary = text.bodyMedium?.copyWith(
      color: c.textSecondary,
    );
    return Semantics(
      container: true,
      label: <String>[
        label,
        spokenValue ?? value,
        ?detail,
      ].where((String s) => s.isNotEmpty).join(', '),
      excludeSemantics: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(CieloSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: secondary),
              Text(value, style: text.displaySmall),
              if (detail != null) Text(detail!, style: secondary),
            ],
          ),
        ),
      ),
    );
  }
}
