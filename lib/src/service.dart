part of './dart_dependency_injection.dart';

/// 可以将这个类混入由依赖注入生成的服务
mixin DependencyInjectionService on Object {
  late final List<WeakReference<_ServiceBoundle>> _boundles = [];
  WeakReference<_ServiceBoundle>? _boundle;

  void _attachToBoundle(_ServiceBoundle boundle) {
    assert(_boundle?.target?.scoped == null || _boundle?.target?.scoped == boundle.scoped, "Don't inject the same service instance into multiple scopes");
    if (_boundle?.target != null) {
      _boundles.add(_boundle!);
    }
    _boundle = WeakReference(boundle);
  }

  ServiceProvider get serviceProvider {
    assert(_boundle?.target?.scoped != null, 'this service create not from dependency injection or this service was disposed');
    return _boundle!.target!.scoped;
  }

  bool _hasBeelInitialize = false;
  bool _hasBeenDispose = false;

  /// 初始化服务
  FutureOr _dependencyInjectionServiceInitialize() {
    // 同一个实例可能会被用于多个服务类型，避免重复初始化
    if (_hasBeelInitialize) return null;
    _hasBeelInitialize = true;
    return dependencyInjectionServiceInitialize();
  }

  /// 释放服务
  void _dependencyInjectionServiceDispose() {
    // 同一个实例可能会被用于多个服务类型，避免重复Dispose
    if (_hasBeenDispose) return;
    _hasBeenDispose = true;
    dispose();
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
    return serviceProvider.buildScoped(builder: builder, boundle: _boundle?.target);
  }

  /// 初始化服务
  FutureOr dependencyInjectionServiceInitialize() {}

  /// 如果你调用了[getService], 你可以立即await [waitLatestServiceInitialize],来等待该服务执行[dependencyInjectionServiceInitialize]
  FutureOr waitLatestServiceInitialize() => serviceProvider.waitLatestServiceInitialize();

  /// 等待当前全部正在初始化的服务完成
  FutureOr waitServicesInitialize() => serviceProvider.waitServicesInitialize();

  /// 当所在的[ServiceProvider]被释放时执行
  void dispose() {}
}
