part of './dart_dependency_injection.dart';

/// 可以将这个类混入由依赖注入生成的服务
mixin DependencyInjectionService on Object {
  bool _isInitDependencyInjectionService = false;
  ServiceObserver? _dependencyInjectionServiceObserver; // 任意服务的观察者
  ServiceObserver? _dependencyInjectionServiceTypedObserver; // 当前类型的服务的观察者
  FutureOr? _serviceInitializeFuture;
  ServiceProvider? _serviceProvider;
  ServiceProvider get serviceProvider {
    assert(_serviceProvider != null, 'this service create not from ioc container');
    return _serviceProvider!;
  }

  bool _hasBeenDispose = false;
  late final List<ServiceProvider> _buildScopedServiceProvides = [];

  /// 初始化服务
  FutureOr _dependencyInjectionServiceInitialize() {
    if (_isInitDependencyInjectionService) return null;
    _isInitDependencyInjectionService = true;
    return dependencyInjectionServiceInitialize();
  }

  /// 获取服务
  T getService<T extends Object>() => serviceProvider.get<T>();

  /// 尝试获取服务，如果服务不存在返回null
  T? tryGetService<T extends Object>() => serviceProvider.tryGet<T>();

  /// 获取服务
  dynamic getServiceByType(Type type) => serviceProvider.getByType(type);

  /// 尝试获取服务，如果服务不存在返回null
  dynamic tryGetServiceByType(Type type) => serviceProvider.tryGetByType(type);

  /// 生成一个范围
  ServiceProvider buildScopedServiceProvider<T>({void Function(ServiceCollection)? builder, Object? scope}) {
    var scopedProvider = serviceProvider.buildScoped(builder: builder, scope: _DependencyInjectionServiceScope(createByService: this, scope: scope));
    _buildScopedServiceProvides.add(scopedProvider);
    return scopedProvider;
  }

  /// 初始化服务
  FutureOr dependencyInjectionServiceInitialize() {}

  /// 如果你调用了[getService], 你可以立即await [waitLatestServiceInitialize],来等待该服务执行[dependencyInjectionServiceInitialize]
  FutureOr waitLatestServiceInitialize() => serviceProvider.waitLatestServiceInitialize();

  /// 等待当前全部正在初始化的服务完成
  FutureOr waitServicesInitialize() => serviceProvider.waitServicesInitialize();

  /// 当所在的[ServiceProvider]被释放时执行
  void dispose() {
    _hasBeenDispose = true;
    final List<ServiceProvider> buildScopedServiceProvides = List<ServiceProvider>.of(_buildScopedServiceProvides);
    _buildScopedServiceProvides.clear();
    for (var element in buildScopedServiceProvides) {
      element.dispose();
    }
  }
}
