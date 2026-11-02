import 'package:flutter_test/flutter_test.dart';
import 'package:auraninja/services/section_order_service.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  String id(String s) => s;

  group('orderByPaths', () {
    test('puts items in the saved order', () {
      expect(orderByPaths(['a', 'b', 'c'], ['c', 'a', 'b'], id),
          ['c', 'a', 'b']);
    });

    test('items missing from the saved order keep their place, at the end',
        () {
      expect(orderByPaths(['a', 'b', 'new1', 'c', 'new2'], ['c', 'a'], id),
          ['c', 'a', 'b', 'new1', 'new2']);
    });

    test('saved paths that no longer exist are ignored', () {
      expect(orderByPaths(['a', 'b'], ['gone', 'b', 'a'], id), ['b', 'a']);
    });

    test('an empty saved order changes nothing', () {
      expect(orderByPaths(['b', 'a'], const [], id), ['b', 'a']);
    });
  });

  group('SectionOrderService', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('round-trips an order per section', () async {
      await SectionOrderService.save('internetRadio', ['x', 'y']);

      expect(await SectionOrderService.load('internetRadio'), ['x', 'y']);
      expect(await SectionOrderService.load('other'), isEmpty);
    });
  });
}
