import 'package:khuta/features/journal/data/journal_entry.dart';
import 'package:khuta/features/journal/data/journal_local_data_source.dart';

class JournalRepository {
  const JournalRepository({JournalLocalDataSource? local})
      : _local = local ?? const JournalLocalDataSource();

  final JournalLocalDataSource _local;

  List<JournalEntry> readAll() => _local.readAll();

  Future<void> save(JournalEntry entry) => _local.write(entry);

  Future<void> remove(String id) => _local.remove(id);
}
