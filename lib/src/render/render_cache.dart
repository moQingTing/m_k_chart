import 'dart:collection';
import 'dart:ui';

import 'package:flutter/painting.dart';

import '../viewport/viewport.dart';
import 'chart_layer_geometry.dart';
import 'render_snapshot.dart';

enum RenderCacheKind {
  window,
  extrema,
  panelRange,
  text,
  path,
  picture,
}

final class RenderCacheStats {
  RenderCacheStats._(
    Map<RenderCacheKind, int> hits,
    Map<RenderCacheKind, int> misses,
  )   : hits = Map.unmodifiable(hits),
        misses = Map.unmodifiable(misses);

  final Map<RenderCacheKind, int> hits;
  final Map<RenderCacheKind, int> misses;

  int hitCount(RenderCacheKind kind) => hits[kind] ?? 0;
  int missCount(RenderCacheKind kind) => misses[kind] ?? 0;
}

final class ChartVisibleWindow {
  const ChartVisibleWindow({
    required this.range,
    required this.xTransform,
  });

  final VisibleIndexRange range;
  final ChartXTransform xTransform;
}

/// Per-chart bounded render cache. It never owns business state.
final class ChartRenderCache {
  ChartRenderCache({
    int geometryCapacity = 32,
    int textCapacity = 128,
    int pathCapacity = 64,
    int pictureCapacity = 8,
  })  : _windows = _LruCache<Object, ChartVisibleWindow>(geometryCapacity),
        _extrema = _LruCache<Object, ChartVisibleMainExtrema?>(
          geometryCapacity,
        ),
        _ranges = _LruCache<Object, ChartPanelValueRange>(geometryCapacity),
        _texts = _LruCache<Object, TextPainter>(
          textCapacity,
          onEvict: (painter) => painter.dispose(),
        ),
        _paths = _LruCache<Object, Path>(pathCapacity),
        _pictures = _LruCache<Object, Picture>(
          pictureCapacity,
          onEvict: (picture) => picture.dispose(),
        );

  final _LruCache<Object, ChartVisibleWindow> _windows;
  final _LruCache<Object, ChartVisibleMainExtrema?> _extrema;
  final _LruCache<Object, ChartPanelValueRange> _ranges;
  final _LruCache<Object, TextPainter> _texts;
  final _LruCache<Object, Path> _paths;
  final _LruCache<Object, Picture> _pictures;
  final Map<RenderCacheKind, int> _hits = {};
  final Map<RenderCacheKind, int> _misses = {};
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;
  RenderCacheStats get stats => RenderCacheStats._(_hits, _misses);

  ChartVisibleWindow windowFor<TTheme extends Object>(
    RenderSnapshot<TTheme> snapshot,
  ) {
    final key = _viewportKey(snapshot);
    return _resolve(
      kind: RenderCacheKind.window,
      cache: _windows,
      key: key,
      create: () => ChartVisibleWindow(
        range: snapshot.viewport.visibleRange,
        xTransform: ChartXTransform(
          viewport: snapshot.viewport,
          data: snapshot.data,
        ),
      ),
    );
  }

  ChartVisibleMainExtrema? extremaFor<TTheme extends Object>(
    RenderSnapshot<TTheme> snapshot,
  ) {
    final key = _mainGeometryKey(snapshot);
    return _resolve(
      kind: RenderCacheKind.extrema,
      cache: _extrema,
      key: key,
      create: () => ChartLayerGeometry.visibleMainExtrema(snapshot),
    );
  }

  ChartPanelValueRange panelRangeFor<TTheme extends Object>(
    RenderSnapshot<TTheme> snapshot,
    String panelId,
  ) {
    final panel = snapshot.layout.panel(panelId);
    final key = (
      _viewportKey(snapshot),
      snapshot.versions.layout,
      panelId,
      panel.spec.kind == ChartPanelKind.main ? snapshot.mainMode : null,
    );
    return _resolve(
      kind: RenderCacheKind.panelRange,
      cache: _ranges,
      key: key,
      create: () => ChartLayerGeometry.rangeFor(
        snapshot,
        panelId,
        mainExtrema: extremaFor(snapshot),
      ),
    );
  }

  TextPainter textPainter({
    required String text,
    required Color color,
    required double fontSize,
  }) {
    _ensureActive();
    if (!fontSize.isFinite || fontSize <= 0) {
      throw ArgumentError.value(fontSize, 'fontSize');
    }
    final key = (text, color.toARGB32(), fontSize);
    return _resolve(
      kind: RenderCacheKind.text,
      cache: _texts,
      key: key,
      create: () => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(color: color, fontSize: fontSize),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(),
    );
  }

  Path path(Object key, Path Function() create) => _resolve(
        kind: RenderCacheKind.path,
        cache: _paths,
        key: key,
        create: create,
      );

  Picture picture(Object key, Picture Function() create) => _resolve(
        kind: RenderCacheKind.picture,
        cache: _pictures,
        key: key,
        create: create,
      );

  void clear() {
    _ensureActive();
    _clearStorage();
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }
    _clearStorage();
    _isDisposed = true;
  }

  T _resolve<T>({
    required RenderCacheKind kind,
    required _LruCache<Object, T> cache,
    required Object key,
    required T Function() create,
  }) {
    _ensureActive();
    final cached = cache.remove(key);
    if (cached.found) {
      _hits[kind] = (_hits[kind] ?? 0) + 1;
      cache.put(key, cached.value as T);
      return cached.value as T;
    }
    _misses[kind] = (_misses[kind] ?? 0) + 1;
    final value = create();
    cache.put(key, value);
    return value;
  }

  Object _viewportKey<TTheme extends Object>(
    RenderSnapshot<TTheme> snapshot,
  ) =>
      (
        snapshot.data.version,
        snapshot.versions.data,
        snapshot.versions.viewport,
        snapshot.viewport,
      );

  Object _mainGeometryKey<TTheme extends Object>(
    RenderSnapshot<TTheme> snapshot,
  ) =>
      (_viewportKey(snapshot), snapshot.mainMode);

  void _clearStorage() {
    _windows.clear();
    _extrema.clear();
    _ranges.clear();
    _texts.clear();
    _paths.clear();
    _pictures.clear();
  }

  void _ensureActive() {
    if (_isDisposed) {
      throw StateError('ChartRenderCache has been disposed.');
    }
  }
}

final class _CacheLookup<T> {
  const _CacheLookup.missing()
      : found = false,
        value = null;

  const _CacheLookup.found(this.value) : found = true;

  final bool found;
  final T? value;
}

final class _LruCache<K, V> {
  _LruCache(this.capacity, {this.onEvict}) {
    if (capacity <= 0) {
      throw ArgumentError.value(capacity, 'capacity', 'Must be positive.');
    }
  }

  final int capacity;
  final void Function(V value)? onEvict;
  final LinkedHashMap<K, V> _values = LinkedHashMap<K, V>();

  _CacheLookup<V> remove(K key) {
    if (!_values.containsKey(key)) {
      return const _CacheLookup.missing();
    }
    return _CacheLookup.found(_values.remove(key) as V);
  }

  void put(K key, V value) {
    _values[key] = value;
    if (_values.length > capacity) {
      final oldestKey = _values.keys.first;
      final evicted = _values.remove(oldestKey) as V;
      onEvict?.call(evicted);
    }
  }

  void clear() {
    if (onEvict != null) {
      for (final value in _values.values) {
        onEvict!(value);
      }
    }
    _values.clear();
  }
}
