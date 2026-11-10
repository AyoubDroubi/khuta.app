import 'package:khuta/core/database/local_store.dart';
import 'package:khuta/features/journeys/data/journey.dart';

class JourneyLocalDataSource {
  const JourneyLocalDataSource();

  List<Journey> readAll() => LocalStore.readJourneys();

  Future<void> write(Journey journey) => LocalStore.writeJourney(journey);

  Future<void> remove(String id) => LocalStore.removeJourney(id);
}
