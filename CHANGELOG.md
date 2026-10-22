# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-10-22

### Added
- Added the V2 `KChart` widget and `KChartController` with immutable K-line series, versioned snapshots, data sessions, viewport/navigation commands, selection state, and history-loading contracts.
- Added configurable built-in and custom indicator definitions, parameter metadata, renderer/legend descriptors, and per-instance indicator bindings.
- Added chart overlays and drawing contracts, including price lines, event/value markers, drawing snapshots, editing, and undo/redo support in the SDK example.
- Added configurable chart options, panel layout, themes, labels, value formatting, and JSON-safe user preferences while keeping the V1 API available.
- Added minimal integration, custom-indicator, settings, live-data, and drawing examples, plus migration and V2 integration documentation.

### Changed
- Exposed the reviewed V2 API only through `package:m_k_chart/m_k_chart.dart`; internal Renderer, Store, coordination, and Widget State remain private.
- Improved incremental K-line processing, indicator/cache reuse, selection stability, and layer invalidation for data, viewport, selection, theme, and clock changes.
- Updated the Demo to use Binance market data and separated example data-source behavior from the SDK's rendering and controller responsibilities.

### Compatibility
- Kept `KChartWidget` and the existing V1 models and helpers available for gradual migration.
- V2 types are now part of the stable 2.x public API; applications should depend on the formal package entry point rather than `src` paths.

## [1.0.4] - 2024-12-19

### Changed
- Changed license from Apache-2.0 to MIT License

## [1.0.3] - 2024-12-19

### Changed
- Replaced video demonstration with image screenshots in README

## [1.0.2] - 2024-12-19

### Fixed
- Fixed video link format in README for pub.dev compatibility

## [1.0.1] - 2024-12-19

### Changed
- Updated documentation and README

## [1.0.0] - 2024-12-19

### Added
- Initial release
- K-line chart widget with support for multiple indicators
- **Main chart indicators**:
  - MA (Moving Average): MA5, MA10, MA20, MA30
  - BOLL (Bollinger Bands): Upper, Middle, Lower bands
  - EMA (Exponential Moving Average): Configurable periods with custom colors
  - SAR (Parabolic SAR): Parabolic Stop and Reverse indicator with circular markers
- **Secondary indicators**:
  - MACD: With hollow/solid bars based on trend direction
  - KDJ: Stochastic oscillator
  - RSI: Relative Strength Index
  - WR: Williams %R
  - VOL: Volume with MA5 and MA10
  - OBV: On-Balance Volume with moving average
- Depth chart widget for order book visualization
- Customizable colors and styles
- Support for light and dark modes
- Interactive gestures: zoom, pan, long press to view details
- Custom formatters for price, volume, and date
- Real-time data update support via `addLastData()` and `updateLastData()`

### Changed
- Extracted from internal project to standalone package
- Removed dependency on internal AppColors class
- ChartColors now requires upColor and downColor parameters
- MACD bars now display as hollow or solid based on trend direction (increasing/decreasing)

### Fixed
- Fixed SAR calculation algorithm to follow standard Parabolic SAR formula
- Fixed MACD rendering to properly show hollow/solid bars
- Fixed various code quality issues (unused variables, imports, null checks)
- Fixed trailing comma and const keyword warnings for better code style
