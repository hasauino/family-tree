import 'package:integration_test/integration_test_driver.dart';

/// Driver entrypoint for running the `integration_test/` suite on Chromium:
///
///   chromedriver --port=4444 &
///   flutter drive \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/add_child_test.dart \
///     -d chrome
Future<void> main() => integrationDriver();
