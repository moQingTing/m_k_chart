/// Demo 绘图快照的宿主存储边界。
///
/// SDK 只产出/消费版本化 JSON；正式应用可在自己的宿主层实现此接口，
/// 接入文件、数据库或偏好存储，而不让图表核心依赖具体持久化插件。
abstract interface class V2DemoDrawingSnapshotStore {
  Future<String?> read(String key);

  Future<void> write(String key, String snapshotJson);
}

/// 验收 Demo 使用的进程内存实现，仅用于示例和测试。
///
/// 同一实例可以跨页面重建读取，但应用进程退出后数据不会保留。
final class V2MemoryDrawingSnapshotStore implements V2DemoDrawingSnapshotStore {
  final Map<String, String> _snapshots = {};

  @override
  Future<String?> read(String key) async => _snapshots[key];

  @override
  Future<void> write(String key, String snapshotJson) async {
    _snapshots[key] = snapshotJson;
  }
}
