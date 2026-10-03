import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/shared/widgets/topology_canvas_viewer.dart';

/// Purpose: Test the shared topology canvas viewer: taps, drag, wheel pan,
/// Ctrl + wheel zoom, and the pan limits.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: The viewer is pumped bare at 400 × 300 over a 1000 × 800 canvas
/// with one tappable box at (20, 20).
void main() {
  late TransformationController controller;
  late List<String> taps;

  setUp(() {
    controller = TransformationController();
    taps = [];
  });

  tearDown(() => controller.dispose());

  /// Purpose: Pump the viewer.
  /// Inputs: `tester`.
  /// Returns: `Future<void>`.
  /// Side effects: Pumps the tree.
  /// Notes: None.
  Future<void> pump(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 300);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: TopologyCanvasViewer(
          canvasSize: const Size(1000, 800),
          controller: controller,
          onBackgroundTap: () => taps.add('background'),
          child: Stack(
            children: [
              Positioned(
                left: 20,
                top: 20,
                width: 60,
                height: 40,
                child: GestureDetector(
                  key: const Key('box'),
                  onTap: () => taps.add('box'),
                  child: const ColoredBox(color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Offset translation() {
    final t = controller.value.getTranslation();
    return Offset(t.x, t.y);
  }

  double scale() => controller.value.getMaxScaleOnAxis();

  testWidgets('a tap reaches the node, or the background', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('box')));
    await tester.tapAt(const Offset(300, 200));
    expect(taps, ['box', 'background']);
  });

  testWidgets('a drag pans and a tap still works after it', (tester) async {
    await pump(tester);
    await tester.dragFrom(const Offset(300, 200), const Offset(-100, -50));
    await tester.pump();
    // The recognizer claims the drag after the touch slop, so the canvas
    // follows the finger from there.
    expect(translation().dx, inInclusiveRange(-100, -60));
    expect(translation().dy, inInclusiveRange(-50, -25));
    expect(taps, isEmpty);
    // The box moved off-screen with the canvas, so this tap hits background.
    await tester.tapAt(const Offset(50, 40));
    expect(taps, ['background']);
  });

  testWidgets('the wheel pans; Shift pans sideways', (tester) async {
    await pump(tester);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(const Offset(200, 150)));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 60)));
    await tester.pump();
    expect(translation(), const Offset(0, -60));
    expect(scale(), 1);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 40)));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(translation(), const Offset(-40, -60));
  });

  testWidgets('Ctrl + wheel zooms about the cursor', (tester) async {
    await pump(tester);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    const at = Offset(100, 100);
    await tester.sendEventToBinding(pointer.hover(at));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -100)));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(scale(), greaterThan(1));
    // The canvas point under the cursor stays under it.
    final scene = (at - translation()) / scale();
    expect(scene.dx, closeTo(100, 1e-6));
    expect(scene.dy, closeTo(100, 1e-6));
  });

  testWidgets('pans stop at the boundary margin', (tester) async {
    await pump(tester);
    await tester.dragFrom(const Offset(300, 200), const Offset(5000, 5000));
    await tester.pump();
    expect(
      translation(),
      const Offset(topologyBoundaryMargin, topologyBoundaryMargin),
    );
  });

  group('clampTopologyTranslation', () {
    test('a canvas larger than the viewport may show the margin only', () {
      final t = clampTopologyTranslation(
        1,
        const Offset(-5000, 5000),
        canvas: const Size(1000, 800),
        viewport: const Size(400, 300),
        margin: 100,
      );
      expect(t, const Offset(400 - 1100, 100));
    });

    test('a smaller canvas stays fully visible', () {
      final t = clampTopologyTranslation(
        1,
        const Offset(-50, 500),
        canvas: const Size(100, 100),
        viewport: const Size(400, 300),
        margin: 0,
      );
      expect(t, const Offset(0, 200));
    });
  });
}
