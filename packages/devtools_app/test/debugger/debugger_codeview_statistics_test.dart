// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/debugger/breakpoint_manager.dart';
import 'package:devtools_app/src/screens/debugger/codeview.dart';
import 'package:devtools_app/src/screens/debugger/codeview_controller.dart';
import 'package:devtools_app/src/screens/debugger/debugger_controller.dart';
import 'package:devtools_app/src/screens/debugger/debugger_screen.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/common_widgets.dart';
import 'package:devtools_app/src/shared/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/notifications.dart';
import 'package:devtools_app/src/shared/scripts/script_manager.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  const windowSize = Size(4000.0, 4000.0);
  late FakeServiceManager fakeServiceManager;
  late MockDebuggerController debuggerController;
  late MockCodeViewController codeViewController;
  late ScriptsHistory scriptsHistory;
  late ValueNotifier<bool> showCodeCoverage;
  late ValueNotifier<bool> showProfileHits;
  bool refreshCodeCoverageInvoked = false;

  setUpAll(() {
    setGlobal(BreakpointManager, BreakpointManager());
    fakeServiceManager = FakeServiceManager();
    codeViewController = createMockCodeViewControllerWithDefaults();
    debuggerController = createMockDebuggerControllerWithDefaults(
      mockCodeViewController: codeViewController,
    );
    scriptsHistory = ScriptsHistory();

    final app = fakeServiceManager.connectedApp!;
    mockConnectedApp(
      app,
      isFlutterApp: false,
      isProfileBuild: false,
      isWebApp: false,
    );
    when(fakeServiceManager.connectedApp!.isProfileBuildNow).thenReturn(false);
    when(fakeServiceManager.connectedApp!.isDartWebAppNow).thenReturn(false);
    setGlobal(ServiceConnectionManager, fakeServiceManager);
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(ScriptManager, MockScriptManager());
    setGlobal(NotificationService, NotificationService());
    scriptsHistory.pushEntry(mockScript!);
    final mockCodeViewController = debuggerController.codeViewController;

    when(mockCodeViewController.currentScriptRef)
        .thenReturn(ValueNotifier(mockScriptRef));
    when(mockCodeViewController.currentParsedScript)
        .thenReturn(ValueNotifier(mockParsedScript));
    when(mockCodeViewController.scriptsHistory).thenReturn(scriptsHistory);

    showCodeCoverage = ValueNotifier<bool>(false);
    showProfileHits = ValueNotifier<bool>(false);
    when(mockCodeViewController.toggleShowCodeCoverage()).thenAnswer(
      (_) => showCodeCoverage.value = !showCodeCoverage.value,
    );
    when(mockCodeViewController.toggleShowProfileInformation()).thenAnswer(
      (_) => showProfileHits.value = !showProfileHits.value,
    );
    when(mockCodeViewController.showCodeCoverage).thenReturn(showCodeCoverage);
    when(mockCodeViewController.showProfileInformation)
        .thenReturn(showProfileHits);
    refreshCodeCoverageInvoked = false;
    // ignore: discarded_futures
    when(mockCodeViewController.refreshCodeStatistics()).thenAnswer(
      (_) async => refreshCodeCoverageInvoked = true,
    );
  });

  Future<void> pumpDebuggerScreen(
    WidgetTester tester,
    DebuggerController controller,
  ) async {
    await tester.pumpWidget(
      wrapWithControllers(
        const DebuggerScreenBody(),
        debugger: controller,
      ),
    );
  }

  void gutterItemProfileInfoTester(WidgetTester tester, bool showProfileInfo) {
    final gutterItems = tester.widgetList<ProfileInformationGutterItem>(
      find.byType(ProfileInformationGutterItem),
    );
    if (!showProfileInfo) {
      expect(gutterItems.isEmpty, true);
    } else {
      expect(gutterItems.length, profilerEntries.length);
    }
  }

  void gutterItemCoverageTester(WidgetTester tester, bool showCoverage) {
    final gutterItems = tester.widgetList<GutterItem>(find.byType(GutterItem));
    for (final item in gutterItems) {
      if (item.isExecutable) {
        expect(
          coverageHitLines.contains(item.lineNumber) ||
              coverageMissLines.contains(item.lineNumber),
          true,
        );
        if (showCoverage) {
          expect(item.coverageHit!, coverageHitLines.contains(item.lineNumber));
        } else {
          expect(item.coverageHit, isNull);
        }
      }
    }
  }

  testWidgetsWithWindowSize('Gutter displays code statistics info', windowSize,
      (WidgetTester tester) async {
    await pumpDebuggerScreen(tester, debuggerController);

    final findCoverageToggle = find.text('Show Coverage');
    final findProfileToggle = find.text('Show Profile');
    final findRefresh = find.byType(IconLabelButton);
    expect(findCoverageToggle, findsOneWidget);
    expect(findProfileToggle, findsOneWidget);
    expect(findRefresh, findsOneWidget);

    // Coverage display starts disabled.
    gutterItemCoverageTester(tester, false);
    gutterItemProfileInfoTester(tester, false);
    expect(
      tester.widget<IconLabelButton>(findRefresh).onPressed,
      isNull,
    );

    // Toggle showing coverage and verify the gutter items contain coverage
    // information.
    await tester.tap(findCoverageToggle);
    await pumpDebuggerScreen(tester, debuggerController);
    gutterItemCoverageTester(tester, true);
    gutterItemProfileInfoTester(tester, false);
    expect(
      tester.widget<IconLabelButton>(findRefresh).onPressed,
      isNotNull,
    );

    // Toggle showing profiler information and verify the gutter items contain
    // profiling information.
    await tester.tap(findProfileToggle);
    await pumpDebuggerScreen(tester, debuggerController);
    gutterItemCoverageTester(tester, true);
    gutterItemProfileInfoTester(tester, true);
    expect(
      tester.widget<IconLabelButton>(findRefresh).onPressed,
      isNotNull,
    );

    // Test the refresh coverage button.
    await tester.tap(findRefresh);
    await pumpDebuggerScreen(tester, debuggerController);
    expect(refreshCodeCoverageInvoked, true);

    // Toggle again and verify the coverage information is no longer present.
    await tester.tap(findCoverageToggle);
    await pumpDebuggerScreen(tester, debuggerController);
    gutterItemCoverageTester(tester, false);
    gutterItemProfileInfoTester(tester, true);
    expect(
      tester.widget<IconLabelButton>(findRefresh).onPressed,
      isNotNull,
    );

    // Toggle again and verify the profiling information is no longer present.
    await tester.tap(findProfileToggle);
    await pumpDebuggerScreen(tester, debuggerController);
    gutterItemCoverageTester(tester, false);
    gutterItemProfileInfoTester(tester, false);
    expect(
      tester.widget<IconLabelButton>(findRefresh).onPressed,
      isNull,
    );
  });
}
