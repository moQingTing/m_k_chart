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

- **V2 Trading Chart** (default): a V2 Layer trading demo backed by OKX public
  candlestick data, with an automatic deterministic offline fallback. It
  defaults to a candlestick chart and lets you select an OKX instrument,
  period, request size, chart mode, main overlays (MA/EMA/BOLL/SAR/VWAP), and
  secondary indicators (VOL/MACD/KDJ/RSI/WR/OBV/ATR/CCI/DMI/ROC/Stoch RSI).
  Secondary indicators can be independently ordered and sized or overlaid in
  a single panel.

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
- `v2_chart_demo.dart`: V2 Layer pipeline, market/indicator controls, and panel layout
- `okx_market_data_client.dart`: public OKX candle client, parser, and injectable transport
- `pubspec.yaml`: Dependencies configuration

## Customization

You can customize the charts by:
- Changing `ChartColors` to modify colors
- Modifying `ChartStyle` to adjust text sizes and formatting
- Providing custom `priceFormatter` and `volumeFormatter` callbacks
- Adjusting `MainState` and `SecondaryState` for different indicators
