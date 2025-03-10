// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/screens/debugger/breakpoint_manager.dart';
import 'package:devtools_app/src/screens/debugger/debugger_controller.dart';
import 'package:devtools_app/src/screens/debugger/debugger_screen.dart';
import 'package:devtools_app/src/screens/debugger/program_explorer_model.dart';
import 'package:devtools_app/src/service/service_manager.dart';
import 'package:devtools_app/src/shared/config_specific/ide_theme/ide_theme.dart';
import 'package:devtools_app/src/shared/globals.dart';
import 'package:devtools_app/src/shared/notifications.dart';
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
    isFlutterApp: true,
    isProfileBuild: false,
    isWebApp: false,
  );
  setGlobal(ServiceConnectionManager, fakeServiceManager);
  setGlobal(IdeTheme, IdeTheme());
  setGlobal(NotificationService, NotificationService());
  setGlobal(ScriptManager, scriptManager);
  setGlobal(BreakpointManager, BreakpointManager());
  fakeServiceManager.consoleService.ensureServiceInitialized();
  when(fakeServiceManager.errorBadgeManager.errorCountNotifier('debugger'))
      .thenReturn(ValueNotifier<int>(0));
  final mockProgramExplorerController =
      createMockProgramExplorerControllerWithDefaults();
  final mockCodeViewController = createMockCodeViewControllerWithDefaults(
    mockProgramExplorerController: mockProgramExplorerController,
  );
  final debuggerController = createMockDebuggerControllerWithDefaults(
    mockCodeViewController: mockCodeViewController,
  );
  final scripts = [
    ScriptRef(uri: 'package:test/script.dart', id: 'test-script')
  ];

  when(scriptManager.sortedScripts).thenReturn(ValueNotifier(scripts));

  when(mockProgramExplorerController.rootObjectNodes).thenReturn(
    ValueNotifier(
      [
        VMServiceObjectNode(
          mockCodeViewController.programExplorerController,
          'package:test',
          null,
        ),
      ],
    ),
  );
  when(mockCodeViewController.showFileOpener).thenReturn(ValueNotifier(false));

  // File Explorer view is shown
  when(mockCodeViewController.fileExplorerVisible)
      .thenReturn(ValueNotifier(true));

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

  testWidgetsWithWindowSize('File Explorer visible', windowSize,
      (WidgetTester tester) async {
    await pumpDebuggerScreen(tester, debuggerController);
    // One for the button and one for the title of the File Explorer view.
    expect(find.text('File Explorer'), findsNWidgets(2));

    // test for items in the libraries tree
    expect(find.text(scripts.first.uri!.split('/').first), findsOneWidget);
  });
}
