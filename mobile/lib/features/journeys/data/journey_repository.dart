import 'package:khuta/features/journeys/data/journey.dart';
import 'package:khuta/features/journeys/data/journey_local_data_source.dart';

class JourneyRepository {
  const JourneyRepository({JourneyLocalDataSource? local})
      : _local = local ?? const JourneyLocalDataSource();

  final JourneyLocalDataSource _local;

  List<Journey> readAll() => _local.readAll();

  Future<void> save(Journey journey) => _local.write(journey);

  Future<void> remove(String id) => _local.remove(id);
}
