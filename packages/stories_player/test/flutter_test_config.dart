import 'dart:async';

import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

/// Every widget test also checks that nothing the player creates leaks:
/// controllers, notifiers, sessions and animation controllers must all be
/// disposed.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  LeakTesting.enable();
  LeakTesting.settings = LeakTesting.settings.withIgnored(
    createdByTestHelpers: true,
  );
  await testMain();
}
