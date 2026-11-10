import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shiguang_radio/audio/radio_handler.dart';
import 'package:shiguang_radio/providers.dart';
import 'radio_handler_test.dart' show FakeEngine;
import 'layout_test.dart' show TestCatalog;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('旧收藏顺序保留，筛选后重排只移动可见项，重建后仍保留顺序', () async {
    SharedPreferences.setMockInitialValues({
      'favorites': ['one', 'hidden', 'two'],
    });
    final prefs = await SharedPreferences.getInstance();
    final handler = RadioHandler(FakeEngine());
    final container = ProviderContainer(
      overrides: [
        preferencesProvider.overrideWithValue(prefs),
        radioProvider.overrideWithValue(handler),
        catalogProvider.overrideWith(TestCatalog.new),
      ],
    );
    expect(container.read(libraryProvider).favorites, ['one', 'hidden', 'two']);
    await container
        .read(libraryProvider.notifier)
        .reorderFavorites(['one', 'two'], 0, 1);
    expect(container.read(libraryProvider).favorites, ['two', 'hidden', 'one']);
    expect(prefs.getStringList('favorites'), ['two', 'hidden', 'one']);
    container.invalidate(libraryProvider);
    expect(container.read(libraryProvider).favorites, ['two', 'hidden', 'one']);
    container.dispose();
    await handler.dispose();
  });
}
