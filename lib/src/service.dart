part of './dart_dependency_injection.dart';

/// with [DependencyInjectionService] only for service from [ServiceProvider]
mixin DependencyInjectionService on Object {
  late final List<_ServiceBoundle> _boundles = [];
  _ServiceBoundle? _boundle;
  FutureOr? _initializeResult;

  FutureOr _attachToBoundle(_ServiceBoundle boundle) {
    assert(() {
      if (_boundle?.scoped != null && _boundle?.scoped != boundle.scoped) {
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
      _dispose();
    }
  }

  /// get service provider
  ServiceProvider get serviceProvider {
    assert(_boundle?.scoped != null, 'this service create not from dependency injection or this service was disposed');
    return _boundle!.scoped;
  }

  /// get service in current scope
  T getService<T extends Object>() => serviceProvider.get<T>();

  /// get service in current scope
  T? tryGetService<T extends Object>() => serviceProvider.tryGet<T>();

  /// try get service in current scope
  dynamic getServiceByType(Type type) => serviceProvider.getByType(type);

  /// try get service in current scope
  dynamic tryGetServiceByType(Type type) => serviceProvider.tryGetByType(type);

  /// build a scoped service provider from current service provider
  ServiceProvider buildScopedServiceProvider<T>({void Function(ServiceCollection)? builder, Object? scope}) {
    var scopedProvider = serviceProvider.buildScoped(builder: builder, scope: _BuildFromServiceScope(createByService: _boundle!, scope: scope));
    _boundle?.scopedProvider.add(scopedProvider);
    return scopedProvider;
  }

  /// that method will be executed immediately after creation.
  FutureOr dependencyInjectionServiceInitialize() {}

  /// same as [ServiceProvider.waitLatestServiceInitialize]
  FutureOr waitLatestServiceInitialize() => serviceProvider.waitLatestServiceInitialize();

  /// same as [ServiceProvider.waitServicesInitialize]
  FutureOr waitServicesInitialize() => serviceProvider.waitServicesInitialize();

  bool _disposed = false;

  /// dispose当前服务
  ///
  /// [fromUser] 是否是用户主动调用的dispose
  void _dispose({bool fromUser = false}) {
    if (_disposed) return;
    _disposed = true;

    if (fromUser) {
      assert(_boundle != null, 'this service create not from dependency injection or this service was disposed');
      for (var element in List.of(_boundles)) {
        element.dispose();
      }
    } else {
      dispose();
    }
    assert(_boundles.isEmpty);
  }

  /// 当所在的[ServiceProvider]被释放时执行
  @mustCallSuper
  void dispose() {
    _dispose(fromUser: true);
  }
}
