// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app/src/screens/memory/panes/leaks/diagnostics/model.dart';
import 'package:devtools_app/src/screens/memory/shared/heap/model.dart';
import 'package:devtools_app/src/screens/memory/shared/primitives/class_name.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker/devtools_integration.dart';

void main() {
  test('$NotGCedAnalyzerTask serializes.', () {
    final task = NotGCedAnalyzerTask(
      reports: [
        LeakReport(
          type: 'type',
          context: const <String, dynamic>{},
          code: 2,
          trackedClass: 'trackedClass',
        )
      ],
      heap: AdaptedHeapData(
        [
          AdaptedHeapObject(
            heapClass: HeapClassName(
              className: 'class',
              library: 'library',
            ),
            references: [2, 3, 4],
            code: 6,
            shallowSize: 1,
          ),
        ],
        rootIndex: 0,
      ),
    );

    final json = task.toJson();

    expect(
      jsonEncode(json),
      jsonEncode(NotGCedAnalyzerTask.fromJson(json).toJson()),
    );
  });
}
