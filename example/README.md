# m_k_chart Example

This is an example Flutter application demonstrating how to use the `m_k_chart` package.

## Running the Example

1. Navigate to the example directory:
   ```bash
   cd example
   ```

2. Get the dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

## Features Demonstrated

- **V2 Trading Chart toolbar** (default): offline deterministic V2 Layer demo
  with period buttons (`1m` through `1d`) and Candlestick, Hollow, OHLC,
  Heikin-Ashi, Line, and Area modes. Run `flutter run` from `example/`.

- **K-line Chart**: Shows how to use `KChartWidget` with:
  - MA (Moving Average) indicators
  - MACD secondary indicator
  - Custom price and volume formatters
  - Custom colors (green for up, red for down)

- **Depth Chart**: Shows how to use `DepthChart` with:
  - Buy and sell depth data
  - Custom price and volume formatters
  - Custom colors

## Code Structure

- `main.dart`: Main entry point for the V2 toolbar demo
- `v2_chart_demo.dart`: V2 Layer pipeline, period selector, and chart-type toolbar
- `pubspec.yaml`: Dependencies configuration

## Customization

You can customize the charts by:
- Changing `ChartColors` to modify colors
- Modifying `ChartStyle` to adjust text sizes and formatting
- Providing custom `priceFormatter` and `volumeFormatter` callbacks
- Adjusting `MainState` and `SecondaryState` for different indicators
