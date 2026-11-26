import 'package:flutter/material.dart';

import '../../../app/contracts.dart';
import '../../../design/design.dart';
import '../../../ui_kit/ui_kit.dart';
import '../domain/offline_province_map.dart';
import 'province_map_view.dart';

class ObservationMapScreen extends StatefulWidget {
  const ObservationMapScreen({
    super.key,
    required this.map,
    required this.observations,
  });
  final OfflineProvinceMap map;
  final ObservationRepository observations;
  @override
  State<ObservationMapScreen> createState() => _ObservationMapScreenState();
}

class _ObservationMapScreenState extends State<ObservationMapScreen> {
  late final Future<Result<List<Observation>>> _load = _loadAll();

  Future<Result<List<Observation>>> _loadAll() async {
    final items = <Observation>[];
    String? cursor;
    do {
      final result = await widget.observations.list(
        filter: ObservationFilter(status: null),
        cursor: cursor,
        limit: 100,
      );
      switch (result) {
        case Failure<ObservationPage>(:final failure):
          return Failure(failure);
        case Success<ObservationPage>(:final value):
          items.addAll(value.items);
          cursor = value.nextCursor;
      }
    } while (cursor != null);
    return Success(List.unmodifiable(items));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mapa offline')),
    body: FutureBuilder<Result<List<Observation>>>(
      future: _load,
      builder: (context, snapshot) {
        final result = snapshot.data;
        if (result is Failure<List<Observation>>) {
          return const CieloErrorState(
            message: 'No se pudo cargar el mapa de observaciones.',
          );
        }
        if (result is! Success<List<Observation>>) {
          return const Center(child: CircularProgressIndicator());
        }
        final markers = result.value
            .where((o) => o.input.location?.hasCoordinates ?? false)
            .map(
              (o) => OfflineMapMarker(
                id: o.id,
                coordinate: GeoCoordinate(
                  o.input.location!.latitude!,
                  o.input.location!.longitude!,
                ),
              ),
            )
            .toList(growable: false);
        return ListView(
          padding: const EdgeInsets.all(CieloSpace.gutter),
          children: [
            Text(
              '${markers.length} observaciones con coordenadas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: CieloSpace.md),
            ProvinceMapView(map: widget.map, markers: markers, height: 560),
          ],
        );
      },
    ),
  );
}
