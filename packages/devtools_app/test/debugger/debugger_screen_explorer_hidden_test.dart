// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/debugger/breakpoint_manager.dart';
import 'package:devtools_app/src/screens/debugger/debugger_controller.dart';
import 'package:devtools_app/src/screens/debugger/debugger_screen.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/notifications.dart';
import 'package:devtools_app/src/shared/primitives/listenable.dart';
import 'package:devtools_app/src/shared/scripts/script_manager.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

void main() {
  const windowSize = Size(4000.0, 4000.0);
  final fakeServiceManager = FakeServiceManager();
  final scriptManager = MockScriptManager();
  mockConnectedApp(
    fakeServiceManager.connectedApp!,
    isProfileBuild: false,
    isFlutterApp: true,
    isWebApp: false,
  );
  setGlobal(ServiceConnectionManager, fakeServiceManager);
  setGlobal(IdeTheme, IdeTheme());
  setGlobal(ScriptManager, scriptManager);
  setGlobal(NotificationService, NotificationService());
  setGlobal(BreakpointManager, BreakpointManager());
  fakeServiceManager.consoleService.ensureServiceInitialized();
  when(fakeServiceManager.errorBadgeManager.errorCountNotifier('debugger'))
      .thenReturn(ValueNotifier<int>(0));
  final debuggerController = createMockDebuggerControllerWithDefaults();
  final codeViewController = debuggerController.codeViewController;

  final scripts = [
    ScriptRef(uri: 'package:/test/script.dart', id: 'test-script')
  ];

  when(scriptManager.sortedScripts).thenReturn(ValueNotifier(scripts));
  when(codeViewController.showFileOpener).thenReturn(ValueNotifier(false));
  when(codeViewController.showProfileInformation).thenReturn(
    const FixedValueListenable(false),
  );

  // File Explorer view is hidden
  when(codeViewController.fileExplorerVisible).thenReturn(ValueNotifier(false));

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

  testWidgetsWithWindowSize('File Explorer hidden', windowSize,
      (WidgetTester tester) async {
    await pumpDebuggerScreen(tester, debuggerController);
    expect(find.text('File Explorer'), findsOneWidget);
  });
}
