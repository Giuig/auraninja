// Host side of `flutter drive` for the integration tests that run in a profile
// build (integration_test/store_screenshots_test.dart). It waits for the
// on-device test and exits non-zero when that test failed.
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
