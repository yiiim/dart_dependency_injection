part of './dart_dependency_injection.dart';

/// 可以将这个类混入由依赖注入生成的服务
mixin DependencyInjectionService on Object {
  ServiceProvider? _serviceProvider;
  ServiceProvider get serviceProvider {
    assert(_serviceProvider != null, 'this service create not from ioc container');
    return _serviceProvider!;
  }

  /// 获取服务
  T getService<T extends Object>() => serviceProvider.get<T>();

  /// 生成一个范围
  ServiceProvider buildScopeService<T>({void Function(ServiceCollection)? builder, Object? scope}) => serviceProvider.buildScope(builder: builder, scope: scope);

  /// 初始化服务
  FutureOr dependencyInjectionServiceInitialize() {}

  /// 如果你调用了[getService], 你可以立即await [waitLatestServiceInitialize],来等待该服务执行[dependencyInjectionServiceInitialize]
  FutureOr waitLatestServiceInitialize() => serviceProvider.waitLatestServiceInitialize();

  /// 当所在的[ServiceProvider]被释放时执行
  void dispose() {}
}
