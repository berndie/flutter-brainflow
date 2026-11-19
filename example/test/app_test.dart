// Drives the example against the real native library (synthetic board).
import 'package:flutter_brainflow/flutter_brainflow.dart';
import 'package:flutter_brainflow_example/main.dart';
import 'package:flutter_brainflow_example/signal_plot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(BoardShim.disableBoardLogger);

  testWidgets('connect, stream into the plot, disconnect', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('Pick a board and connect.'), findsOneWidget);

    // Native calls run in isolates (real time) and data is polled by a
    // Timer (fake time in widget tests): advance both.
    Future<void> settle(Duration d) async {
      await tester.runAsync(() => Future<void>.delayed(d));
      await tester.pump(d);
    }

    await tester.tap(find.text('Connect'));
    await settle(const Duration(milliseconds: 500));
    expect(find.text('ready'), findsOneWidget);

    await tester.tap(find.text('Start'));
    await settle(const Duration(milliseconds: 800));
    expect(find.text('streaming'), findsOneWidget);
    final plot = tester.widget<SignalPlot>(find.byType(SignalPlot));
    expect(plot.buffer.channels, 16);
    expect(plot.buffer.length, greaterThan(50));
    expect(plot.labels.first, 'Fz');

    await tester.tap(find.text('Disconnect'));
    await settle(const Duration(milliseconds: 500));
    expect(find.text('Pick a board and connect.'), findsOneWidget);
  });
}
