import 'package:khuta/core/database/local_store.dart';
import 'package:khuta/features/journal/data/journal_entry.dart';

class JournalLocalDataSource {
  const JournalLocalDataSource();

  List<JournalEntry> readAll() => LocalStore.readJournalEntries();

  Future<void> write(JournalEntry entry) => LocalStore.writeJournalEntry(entry);

  Future<void> remove(String id) => LocalStore.removeJournalEntry(id);
}
