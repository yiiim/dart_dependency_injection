part of './dart_dependency_injection.dart';

/// 服务提供器
class ServiceProvider {
  ServiceProvider(
    this._serviceDescriptors, {
    this.parent,
    this.scope,
  });

  /// 范围标签
  final Object? scope;

  /// 父级，如果不是空，表示这个是一个范围
  final ServiceProvider? parent;

  /// 全部的服务描述
  final Map<Type, ServiceDescriptor> _serviceDescriptors;

  /// [ServiceProvider]中当前正在执行[DependencyInjectionService.dependencyInjectionServiceInitialize]的[Future]
  final Map<Type, List<Future>> _asyncServiceInitializeProcessByType = {};

  /// [ServiceProvider]最近一个服务执行[DependencyInjectionService.dependencyInjectionServiceInitialize] 的[Future]
  Future? _latestServiceInitializeProcess;

  /// 存储的单例
  final Map<Type, Object> _singletons = {};

  /// 存储的单例
  final List<ServiceProvider> _scopeds = [];

  /// 根据[ServiceDescriptor]获取服务
  ///
  /// [ServiceDescriptor]服务描述
  /// [serviceType]服务类型
  /// [originalProvider]如果是从子级执行的，这个是最开始的子级
  dynamic __get<T extends Object>(ServiceDescriptor serviceDefinition, Type serviceType, {ServiceProvider? originalProvider}) {
    assert(_serviceDescriptors.values.contains(serviceDefinition));
    // 如果是单例
    if (serviceDefinition.isSingleton) {
      final singletonValue = _singletons[serviceType];
      if (singletonValue != null) {
        // 如果这个服务还在初始化
        _latestServiceInitializeProcess = _asyncServiceInitializeProcessByType[serviceType]?.firstOrNull;
        scheduleMicrotask(() => _latestServiceInitializeProcess = null);
        return singletonValue;
      }
    }
    // 如果是范围单例，并且当前不是原始[ServiceProvider],从原始提供者找单例
    if (serviceDefinition.isScopeSingleton) {
      var provider = (originalProvider ?? this);
      final singletonValue = provider._singletons[serviceType];
      if (singletonValue != null) {
        // 如果这个服务还在初始化
        provider._latestServiceInitializeProcess = provider._asyncServiceInitializeProcessByType[serviceType]?.firstOrNull;
        scheduleMicrotask(() => provider._latestServiceInitializeProcess = null);
        return singletonValue;
      }
    }

    // 如果没有找到单例，则需要创建服务
    // 服务所属的[ServiceProvider]为originalProvider，originalProvider为null就是this
    var provider = originalProvider ?? this;
    // 创建服务
    final service = serviceDefinition.factory(provider);
    // 如果服务是 [DependencyInjectionService]类型
    if (service is DependencyInjectionService) {
      var serviceProvider = serviceDefinition.isSingleton ? this : provider;
      assert(service._serviceProvider == null || service._serviceProvider == serviceProvider, "Don't inject the same service instance into multiple scopes");
      // 单例服务所在的范围永远是定义它的范围
      service._serviceProvider = serviceProvider;
      // 初始化服务
      var initResult = (service._serviceInitializeFuture ??= service._dependencyInjectionServiceInitialize());
      // 如果是异步初始化
      if (initResult is Future) {
        // 设置最近的异步future
        provider._latestServiceInitializeProcess = initResult;
        // 仅在获取服务后立即等待最近的异步future有效
        scheduleMicrotask(() => provider._latestServiceInitializeProcess = null);
        // 保存异步future
        _asyncServiceInitializeProcessByType[serviceType] ??= <Future>[];
        _asyncServiceInitializeProcessByType[serviceType]!.add(initResult);
        // 异步初始化结束后
        initResult.then(
          (value) {
            // 移除保存的future
            _asyncServiceInitializeProcessByType[serviceType]!.remove(initResult);
            if (_asyncServiceInitializeProcessByType[serviceType]!.isEmpty) {
              _asyncServiceInitializeProcessByType.remove(serviceType);
            }
            service._serviceInitializeFuture = null;
          },
        );
      }
    }
    // 如果是单例，保存到单例
    if (serviceDefinition.isSingleton) {
      _singletons[serviceType] = service;
    }
    // 如果是范围单例，保存到所属的[ServiceProvider]单例
    if (serviceDefinition.isScopeSingleton) {
      provider._singletons[serviceType] = service;
    }
    return service;
  }

  /// 获取服务
  ///
  /// [originalProvider]如果是从子级执行的，这个是最开始的子级
  dynamic _get(Type serviceType, {ServiceProvider? originalProvider}) {
    final serviceDefinition = _serviceDescriptors[serviceType];
    if (serviceDefinition == null) {
      var service = parent?._get(serviceType, originalProvider: originalProvider ?? this);
      return service;
    }
    return __get(serviceDefinition, serviceType, originalProvider: originalProvider);
  }

  /// 获取服务
  T get<T extends Object>() {
    var service = _get(T);
    if (service == null) {
      throw ServiceNotFoundException(
        'Service ${T.toString()} not found',
      );
    }
    return service;
  }

  /// 尝试获取服务，如果服务不存在返回null
  T? tryGet<T extends Object>() => _get(T);

  /// 根据类型获取服务
  dynamic getByType(Type type) {
    var service = _get(type);
    if (service == null) {
      throw ServiceNotFoundException(
        'Service ${type.toString()} not found',
      );
    }
    return service;
  }

  /// 尝试获取服务，如果服务不存在返回null
  dynamic tryGetByType(Type type) => _get(type);

  /// 等待最近一个获取的服务初始化，即获取的服务执行完[DependencyInjectionService.dependencyInjectionServiceInitialize]
  ///
  /// 在获取服务后必须立即await [waitLatestServiceInitialize]，否则不要await
  FutureOr waitLatestServiceInitialize() => _latestServiceInitializeProcess;

  /// 等待当前全部的服务初始化
  FutureOr waitServicesInitialize() {
    var parentWait = parent?.waitServicesInitialize();
    var selfProcress = _asyncServiceInitializeProcessByType.values.expand((element) => element);
    var futures = <Future>[
      if (parentWait != null) parentWait as Future,
      ...selfProcress,
    ];
    if (futures.isEmpty) return null;
    return Future(
      () async {
        await Future.wait(futures);
        await waitServicesInitialize();
      },
    );
  }

  /// 生成一个范围
  ///
  /// 范围[ServiceProvider]将继承当前[ServiceProvider]的全部服务
  ServiceProvider buildScoped({void Function(ServiceCollection)? builder, Object? scope}) {
    final scopedBuilder = tryGet<ServiceCollection>() ?? ServiceCollection();
    builder?.call(scopedBuilder);
    return scopedBuilder.buildScoped(this);
  }

  /// 释放
  void dispose() {
    for (final element in _singletons.values) {
      if (element is DependencyInjectionService) {
        if (element._hasBeenDispose == false) element.dispose();
      }
    }
    _singletons.clear();
    for (var element in [..._scopeds]) {
      _scopeds.remove(element);
      element.dispose();
    }
    parent?._scopeds.remove(this);
  }
}
