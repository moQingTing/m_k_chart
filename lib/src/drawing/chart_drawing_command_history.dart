import 'chart_drawing_editor.dart';

/// One reversible transition between immutable drawing editor snapshots.
final class ChartDrawingCommand {
  const ChartDrawingCommand({
    required this.label,
    required this.before,
    required this.after,
  });

  final String label;
  final ChartDrawingEditor before;
  final ChartDrawingEditor after;
}

/// Bounded undo/redo history owned by one chart instance.
final class ChartDrawingCommandHistory {
  factory ChartDrawingCommandHistory({
    ChartDrawingEditor? editor,
    int capacity = 100,
  }) {
    if (capacity <= 0) {
      throw ArgumentError.value(capacity, 'capacity', 'Must be positive.');
    }
    return ChartDrawingCommandHistory._(
      editor: editor ?? ChartDrawingEditor(),
      capacity: capacity,
      undoStack: const [],
      redoStack: const [],
    );
  }

  const ChartDrawingCommandHistory._({
    required this.editor,
    required this.capacity,
    required this.undoStack,
    required this.redoStack,
  });

  final ChartDrawingEditor editor;
  final int capacity;
  final List<ChartDrawingCommand> undoStack;
  final List<ChartDrawingCommand> redoStack;
  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;

  ChartDrawingCommandHistory execute(
    String label,
    ChartDrawingEditor Function(ChartDrawingEditor editor) operation,
  ) {
    if (label.trim().isEmpty) throw ArgumentError.value(label, 'label');
    final next = operation(editor);
    if (identical(next, editor)) return this;
    final commands = [
      ...undoStack,
      ChartDrawingCommand(label: label, before: editor, after: next),
    ];
    final trimmed = commands.length <= capacity
        ? commands
        : commands.sublist(commands.length - capacity);
    return ChartDrawingCommandHistory._(
      editor: next,
      capacity: capacity,
      undoStack: List.unmodifiable(trimmed),
      redoStack: const [],
    );
  }

  ChartDrawingCommandHistory undo() {
    if (!canUndo) return this;
    final command = undoStack.last;
    return ChartDrawingCommandHistory._(
      editor: command.before,
      capacity: capacity,
      undoStack: List.unmodifiable(undoStack.sublist(0, undoStack.length - 1)),
      redoStack: List.unmodifiable([...redoStack, command]),
    );
  }

  ChartDrawingCommandHistory redo() {
    if (!canRedo) return this;
    final command = redoStack.last;
    return ChartDrawingCommandHistory._(
      editor: command.after,
      capacity: capacity,
      undoStack: List.unmodifiable([...undoStack, command]),
      redoStack: List.unmodifiable(redoStack.sublist(0, redoStack.length - 1)),
    );
  }
}
