import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/proxies/proxy_latency_button.dart';

void main() {
  testWidgets('latency tap does not select row; drag does not test', (
    tester,
  ) async {
    var selected = 0;
    var tested = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              GestureDetector(
                onTap: () => selected++,
                child: Row(
                  children: [
                    const Expanded(child: Text('Germany')),
                    ProxyLatencyButton(
                      label: 'Test Germany',
                      onPressed: () => tested++,
                      child: const Text('140 ms'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 1600),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('140 ms'));
    await tester.pump();
    expect(tested, 1);
    expect(selected, 0);
    await tester.drag(find.text('140 ms'), const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(tested, 1);
    expect(selected, 0);
  });
  testWidgets('disabled latency action does not fall through', (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GestureDetector(
            onTap: () => selected++,
            child: const ProxyLatencyButton(
              label: 'Test latency',
              child: Text('No data'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('No data'));
    expect(selected, 0);
  });
}
