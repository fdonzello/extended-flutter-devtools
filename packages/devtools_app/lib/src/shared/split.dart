// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'primitives/utils.dart';

/// A widget that takes a list of children, lays them out along [axis], and
/// allows the user to resize them.
///
/// The user can customize the amount of space allocated to each child by
/// dragging a divider between them.
///
/// [initialFractions] defines how much space to give each child when building
/// this widget.
class Split extends StatefulWidget {
  /// Builds a split oriented along [axis].
  Split({
    Key? key,
    required this.axis,
    required this.children,
    required this.initialFractions,
    this.minSizes,
    this.splitters,
  })  : assert(children.length >= 2),
        assert(initialFractions.length >= 2),
        assert(children.length == initialFractions.length),
        super(key: key) {
    _verifyFractionsSumTo1(initialFractions);
    if (minSizes != null) {
      assert(minSizes!.length == children.length);
    }
    if (splitters != null) {
      assert(splitters!.length == children.length - 1);
    }
  }

  /// The main axis the children will lay out on.
  ///
  /// If [Axis.horizontal], the children will be placed in a [Row]
  /// and they will be horizontally resizable.
  ///
  /// If [Axis.vertical], the children will be placed in a [Column]
  /// and they will be vertically resizable.
  ///
  /// Cannot be null.
  final Axis axis;

  /// The children that will be laid out along [axis].
  final List<Widget> children;

  /// The fraction of the layout to allocate to each child in [children].
  ///
  /// The index of [initialFractions] corresponds to the child at index of
  /// [children].
  final List<double> initialFractions;

  /// The minimum size each child is allowed to be.
  final List<double>? minSizes;

  /// Splitter widgets to divide [children].
  ///
  /// If this is null, a default splitter will be used to divide [children].
  final List<PreferredSizeWidget>? splitters;

  /// The key passed to the divider between children[index] and
  /// children[index + 1].
  ///
  /// Visible to grab it in tests.
  @visibleForTesting
  Key dividerKey(int index) => Key('$this dividerKey $index');

  static Axis axisFor(BuildContext context, double horizontalAspectRatio) {
    final screenSize = MediaQuery.of(context).size;
    final aspectRatio = screenSize.width / screenSize.height;
    if (aspectRatio >= horizontalAspectRatio) return Axis.horizontal;
    return Axis.vertical;
  }

  @override
  State<StatefulWidget> createState() => _SplitState();
}

class _SplitState extends State<Split> {
  late final List<double> fractions;

  bool get isHorizontal => widget.axis == Axis.horizontal;

  @override
  void initState() {
    super.initState();
    fractions = List.from(widget.initialFractions);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: _buildLayout);
  }

  Widget _buildLayout(BuildContext context, BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final axisSize = isHorizontal ? width : height;

    final availableSize = axisSize - _totalSplitterSize();

    // Size calculation helpers.
    double _minSizeForIndex(int index) {
      if (widget.minSizes == null) return 0.0;

      double totalMinSize = 0;
      for (var minSize in widget.minSizes!) {
        totalMinSize += minSize;
      }

      // Reduce the min sizes gracefully if the total required min size for all
      // children is greater than the available size for children.
      if (totalMinSize > availableSize) {
        return widget.minSizes![index] * availableSize / totalMinSize;
      } else {
        return widget.minSizes![index];
      }
    }

    double _minFractionForIndex(int index) =>
        _minSizeForIndex(index) / availableSize;

    void _clampFraction(int index) {
      fractions[index] =
          fractions[index].clamp(_minFractionForIndex(index), 1.0);
    }

    double _sizeForIndex(int index) => availableSize * fractions[index];

    double fractionDeltaRequired = 0.0;
    double fractionDeltaAvailable = 0.0;

    double deltaFromMinimumSize(int index) =>
        fractions[index] - _minFractionForIndex(index);

    for (int i = 0; i < fractions.length; ++i) {
      final delta = deltaFromMinimumSize(i);
      if (delta < 0) {
        fractionDeltaRequired -= delta;
      } else {
        fractionDeltaAvailable += delta;
      }
    }
    if (fractionDeltaRequired > 0) {
      // Likely due to a change in the available size, the current fractions for
      // the children do not obey the min size constraints.
      // The min size constraints for children are scaled so it is always
      // possible to meet them. A scaleFactor greater than 1 would indicate that
      // it is impossible to meet the constraints.
      double scaleFactor = fractionDeltaRequired / fractionDeltaAvailable;
      assert(scaleFactor <= 1 + defaultEpsilon);
      scaleFactor = math.min(scaleFactor, 1.0);
      for (int i = 0; i < fractions.length; ++i) {
        final delta = deltaFromMinimumSize(i);
        if (delta < 0) {
          // This is equivalent to adding delta but avoids rounding error.
          fractions[i] = _minFractionForIndex(i);
        } else {
          // Reduce all fractions that are above their minimum size by an amount
          // proportional to their ability to reduce their size without
          // violating their minimum size constraints.
          fractions[i] -= delta * scaleFactor;
        }
      }
    }

    // Determine what fraction to give each child, including enough space to
    // display the divider.
    final sizes = List.generate(fractions.length, (i) => _sizeForIndex(i));

    void updateSpacing(DragUpdateDetails dragDetails, int splitterIndex) {
      final dragDelta =
          isHorizontal ? dragDetails.delta.dx : dragDetails.delta.dy;
      final fractionalDelta = dragDelta / axisSize;

      // Returns the actual delta applied to elements before the splitter.
      double updateSpacingBeforeSplitterIndex(double delta) {
        final startingDelta = delta;
        var index = splitterIndex;
        while (index >= 0) {
          fractions[index] += delta;
          final minFractionForIndex = _minFractionForIndex(index);
          if (fractions[index] >= minFractionForIndex) {
            _clampFraction(index);
            return startingDelta;
          }
          delta = fractions[index] - minFractionForIndex;
          _clampFraction(index);
          index--;
        }
        // At this point, we know that both [startingDelta] and [delta] are
        // negative, and that [delta] represents the overflow that did not get
        // applied.
        return startingDelta - delta;
      }

      // Returns the actual delta applied to elements after the splitter.
      double updateSpacingAfterSplitterIndex(double delta) {
        final startingDelta = delta;
        var index = splitterIndex + 1;
        while (index < fractions.length) {
          fractions[index] += delta;
          final minFractionForIndex = _minFractionForIndex(index);
          if (fractions[index] >= minFractionForIndex) {
            _clampFraction(index);
            return startingDelta;
          }
          delta = fractions[index] - minFractionForIndex;
          _clampFraction(index);
          index++;
        }
        // At this point, we know that both [startingDelta] and [delta] are
        // negative, and that [delta] represents the overflow that did not get
        // applied.
        return startingDelta - delta;
      }

      setState(() {
        // Update the fraction of space consumed by the children. Always update
        // the shrinking children first so that we do not over-increase the size
        // of the growing children and cause layout overflow errors.
        if (fractionalDelta <= 0.0) {
          final appliedDelta =
              updateSpacingBeforeSplitterIndex(fractionalDelta);
          updateSpacingAfterSplitterIndex(-appliedDelta);
        } else {
          final appliedDelta =
              updateSpacingAfterSplitterIndex(-fractionalDelta);
          updateSpacingBeforeSplitterIndex(-appliedDelta);
        }
      });
      _verifyFractionsSumTo1(fractions);
    }

    final children = <Widget>[];
    for (int i = 0; i < widget.children.length; i++) {
      children.addAll([
        SizedBox(
          width: isHorizontal ? sizes[i] : width,
          height: isHorizontal ? height : sizes[i],
          child: widget.children[i],
        ),
        if (i < widget.children.length - 1)
          MouseRegion(
            cursor: isHorizontal
                ? SystemMouseCursors.resizeColumn
                : SystemMouseCursors.resizeRow,
            child: GestureDetector(
              key: widget.dividerKey(i),
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) =>
                  isHorizontal ? updateSpacing(details, i) : null,
              onVerticalDragUpdate: (details) =>
                  isHorizontal ? null : updateSpacing(details, i),
              // DartStartBehavior.down is needed to keep the mouse pointer stuck to
              // the drag bar. There still appears to be a few frame lag before the
              // drag action triggers which is't ideal but isn't a launch blocker.
              dragStartBehavior: DragStartBehavior.down,
              child: widget.splitters != null
                  ? widget.splitters![i]
                  : DefaultSplitter(isHorizontal: isHorizontal),
            ),
          ),
      ]);
    }
    return Flex(
      direction: widget.axis,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  double _totalSplitterSize() {
    final numSplitters = widget.children.length - 1;
    if (widget.splitters == null) {
      return numSplitters * DefaultSplitter.splitterWidth;
    } else {
      var totalSize = 0.0;
      for (var splitter in widget.splitters!) {
        totalSize += isHorizontal
            ? splitter.preferredSize.width
            : splitter.preferredSize.height;
      }
      return totalSize;
    }
  }
}

class DefaultSplitter extends StatelessWidget {
  const DefaultSplitter({required this.isHorizontal});

  static const double iconSize = 24.0;
  static const double splitterWidth = 12.0;

  final bool isHorizontal;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: isHorizontal ? degToRad(90.0) : degToRad(0.0),
      child: Align(
        widthFactor: 0.5,
        heightFactor: 0.5,
        child: Icon(
          Icons.drag_handle,
          size: iconSize,
          color: Theme.of(context).focusColor,
        ),
      ),
    );
  }
}

void _verifyFractionsSumTo1(List<double> fractions) {
  var sumFractions = 0.0;
  for (var fraction in fractions) {
    sumFractions += fraction;
  }
  assert(
    (1.0 - sumFractions).abs() < defaultEpsilon,
    'Fractions should sum to 1.0, but instead sum to $sumFractions:\n$fractions',
  );
}
