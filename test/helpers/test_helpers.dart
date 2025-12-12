import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_image_mock/network_image_mock.dart';

/// Test helper utilities for comprehensive screen testing
/// Provides consistent wrappers for all screen tests

/// Wraps a screen widget with all necessary providers for testing
Widget buildTestableScreen(Widget screen, {List<Override>? overrides}) {
  return ProviderScope(
    overrides: overrides ?? [],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: screen,
    ),
  );
}

/// Pumps a screen with mock network images support
/// Essential for screens that display network images
Future<void> pumpScreenWithMockImages(
  WidgetTester tester,
  Widget screen, {
  List<Override>? overrides,
  Duration? settleTimeout,
}) async {
  await mockNetworkImagesFor(() async {
    await tester.pumpWidget(buildTestableScreen(screen, overrides: overrides));
    await tester.pumpAndSettle(settleTimeout ?? const Duration(seconds: 2));
  });
}

/// Standard test for verifying a screen renders without crash
Future<void> verifyScreenRenders(
  WidgetTester tester,
  Widget screen, {
  String? expectedTitle,
  List<Override>? overrides,
}) async {
  await pumpScreenWithMockImages(tester, screen, overrides: overrides);
  
  // Basic render verification
  expect(tester.takeException(), isNull, reason: 'Screen threw exception during render');
  
  if (expectedTitle != null) {
    expect(find.text(expectedTitle), findsOneWidget, reason: 'Expected title "$expectedTitle" not found');
  }
}

/// Verify no overflow errors on screen
Future<void> verifyNoOverflowErrors(WidgetTester tester) async {
  final overflowErrors = tester.takeException();
  expect(overflowErrors, isNull, reason: 'Screen has overflow errors');
}

/// Verify widget exists and is tappable without crash
Future<void> verifyTappable(
  WidgetTester tester,
  Finder finder, {
  String? description,
}) async {
  expect(finder, findsOneWidget, reason: description ?? 'Widget not found');
  await tester.tap(finder);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'Tap caused an exception');
}

/// Verify multiple widgets of type exist
void verifyWidgetsExist<T extends Widget>(
  WidgetTester tester, {
  int? expectedCount,
  String? description,
}) {
  final finder = find.byType(T);
  if (expectedCount != null) {
    expect(finder, findsNWidgets(expectedCount), reason: description);
  } else {
    expect(finder, findsWidgets, reason: description ?? 'Expected ${T.toString()} widgets not found');
  }
}

/// Verify scrolling works without crash
Future<void> verifyScrollable(
  WidgetTester tester, {
  Type scrollableType = ListView,
  double scrollAmount = -500,
}) async {
  final scrollable = find.byType(scrollableType);
  if (scrollable.evaluate().isNotEmpty) {
    await tester.drag(scrollable.first, Offset(0, scrollAmount));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Scroll caused an exception');
    
    // Scroll back
    await tester.drag(scrollable.first, Offset(0, -scrollAmount));
    await tester.pumpAndSettle();
  }
}

/// Find by Key with semantic naming
Finder findByKey(String key) => find.byKey(Key(key));

/// Find button with text
Finder findButton(String text) => find.widgetWithText(ElevatedButton, text);

/// Find icon button
Finder findIconButton(IconData icon) => find.widgetWithIcon(IconButton, icon);

/// Test result reporter
class ScreenTestReport {
  final String screenName;
  final List<String> passedTests = [];
  final List<String> failedTests = [];
  final List<String> warnings = [];
  
  ScreenTestReport(this.screenName);
  
  void addPass(String test) => passedTests.add(test);
  void addFail(String test) => failedTests.add(test);
  void addWarning(String warning) => warnings.add(warning);
  
  bool get allPassed => failedTests.isEmpty;
  
  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('=== $screenName Test Report ===');
    buffer.writeln('✅ Passed: ${passedTests.length}');
    buffer.writeln('❌ Failed: ${failedTests.length}');
    buffer.writeln('⚠️ Warnings: ${warnings.length}');
    
    if (failedTests.isNotEmpty) {
      buffer.writeln('\nFailed tests:');
      for (final test in failedTests) {
        buffer.writeln('  - $test');
      }
    }
    
    if (warnings.isNotEmpty) {
      buffer.writeln('\nWarnings:');
      for (final warning in warnings) {
        buffer.writeln('  - $warning');
      }
    }
    
    return buffer.toString();
  }
}
