import 'package:flutter_test/flutter_test.dart';
import 'package:m_k_chart/src/drawing/drawing.dart';

void main() {
  test('undoes, redoes, and clears redo after a new command', () {
    final second = ChartDrawingCommandHistory(editor: ChartDrawingEditor())
        .execute('add', (editor) => editor.add(_drawing()));
    final undone = second.undo();
    expect(undone.editor.drawings, isEmpty);
    expect(undone.canRedo, isTrue);
    expect(undone.redo().editor.drawings, hasLength(1));
    expect(
      undone.execute('select', (editor) => editor.select(null)).canRedo,
      isFalse,
    );
  });

  test('selection preserves undo and redo history', () {
    final added = ChartDrawingCommandHistory(editor: ChartDrawingEditor())
        .execute('add', (editor) => editor.add(_drawing()));
    final selected = added.select('trend');
    expect(selected.editor.selectedDrawingId, 'trend');
    expect(selected.canUndo, isTrue);
    expect(selected.undo().editor.drawings, isEmpty);

    final selectedAfterUndo = selected.undo().select(null);
    expect(selectedAfterUndo.canRedo, isTrue);
    expect(selectedAfterUndo.redo().editor.drawings, hasLength(1));
  });
}

ChartDrawing _drawing() => ChartDrawing(
      id: 'trend',
      kind: ChartDrawingKind.horizontalLine,
      anchors: [ChartDrawingAnchor(epochMilliseconds: 1, price: 1)],
    );
