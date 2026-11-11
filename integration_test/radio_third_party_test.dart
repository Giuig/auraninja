// The built-in Yumi Co. Radio, with the same checks as the local station.
//
// Third party: depends on a station somebody else runs and on the runner's
// internet access. scripts/ci/run_android_e2e.sh runs this file in its own call
// and reports the result without failing the job.
@Tags(['third_party'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'support/boot.dart';
import 'support/radio.dart';

void main() {
  initE2eBinding();

  testWidgets('Yumi Co. Radio: plays, pauses, resumes and stops',
      timeout: const Timeout(Duration(minutes: 3)), (tester) async {
    final handler = await ensureBooted();
    await checkStationLifecycle(
      handler,
      radioStation('Yumi Co. Radio', kYumiUrl),
      'radio_yumi',
    );
  });
}
