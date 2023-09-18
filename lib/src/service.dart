part of './dart_dependency_injection.dart';

/// 可以将这个类混入由依赖注入生成的服务
mixin DependencyInjectionService on Object {
  late final List<_ServiceBoundle> _boundles = [];
  _ServiceBoundle? _boundle;
  FutureOr? _initializeResult;

  FutureOr _attachToBoundle(_ServiceBoundle boundle) {
    assert(() {
      if (_boundle?.scoped != null || _boundle?.scoped != boundle.scoped) {
        print("Warning ！！ Don't inject the same service instance into multiple scopes，");
      }
      return true;
    }());
    bool runInitialize = _boundles.isEmpty;
    _boundles.add(boundle);
    _boundle = boundle;
    if (runInitialize) {
      var initialize = dependencyInjectionServiceInitialize();
      if (initialize is Future) {
        initialize.then(
          (value) {
            _initializeResult = null;
          },
          onError: (error) {
            _initializeResult = null;
          },
        );
      }
      _initializeResult = initialize;
    }
    return _initializeResult;
  }

  void _detachFromBoundle(_ServiceBoundle boundle) {
    assert(_boundles.contains(boundle));
    _boundles.remove(boundle);
    if (_boundle == boundle) {
      _boundle = _boundles.lastOrNull;
    }
    if (_boundles.isEmpty) {
      dispose();
    }
  }

  ServiceProvider get serviceProvider {
    assert(_boundle?.scoped != null, 'this service create not from dependency injection or this service was disposed');
    return _boundle!.scoped;
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
    var scopedProvider = serviceProvider.buildScoped(builder: builder, scope: _BuildFromServiceScope(createByService: _boundle!, scope: scope));
    _boundle?.scopedProvider.add(scopedProvider);
    return scopedProvider;
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
