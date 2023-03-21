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
        return singletonValue;
      }
    }
    // 如果是范围单例，并且当前不是原始[ServiceProvider],从原始提供者找单例
    if (serviceDefinition.isScopeSingleton && originalProvider != null) {
      final singletonValue = originalProvider._singletons[serviceType];
      if (singletonValue != null) {
        return singletonValue;
      }
    }

    // 如果没有找到单例，则需要创建服务
    // 服务所属的[ServiceProvider]为originalProvider，originalProvider为null就是this
    var provider = originalProvider ?? this;
    // 如果这个服务每次创建都需要创建一个范围，则服务应该属于新创建的范围[ServiceProvider]
    if (serviceDefinition.createUseScope) {
      provider = buildScope(builder: serviceDefinition.useScopeBuilder);
    }
    // 创建服务
    final service = serviceDefinition.factory(provider);
    // 如果服务是 [DependencyInjectionService]类型
    if (service is DependencyInjectionService) {
      service._serviceProvider = provider;
      var initResult = service.dependencyInjectionServiceInitialize();
      if (initResult is Future) {
        _latestServiceInitializeProcess = initResult;
        scheduleMicrotask(() => _latestServiceInitializeProcess = null);
        _asyncServiceInitializeProcessByType[serviceType] ??= <Future>[];
        _asyncServiceInitializeProcessByType[serviceType]!.add(initResult);
        initResult.then(
          (value) {
            _asyncServiceInitializeProcessByType[serviceType]!.remove(initResult);
            if (_asyncServiceInitializeProcessByType[serviceType]!.isEmpty) {
              _asyncServiceInitializeProcessByType.remove(serviceType);
            }
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
      if (service == null) {
        throw ServiceNotFoundException(
          'Service ${serviceType.toString()} not found',
        );
      }
      return service;
    }
    return __get(serviceDefinition, serviceType, originalProvider: originalProvider);
  }

  /// 获取服务
  T get<T extends Object>() => _get(T);

  /// 根据类型获取服务
  dynamic getByType(Type type) => _get(type);

  /// 等待最近一个获取的服务初始化，即执行完[DependencyInjectionService.dependencyInjectionServiceInitialize]
  ///
  /// 在获取服务后必须立即await [waitLatestServiceInitialize]，否则不要await
  FutureOr waitLatestServiceInitialize() => _latestServiceInitializeProcess;

  /// 生成一个范围
  ///
  /// 范围[ServiceProvider]将继承当前[ServiceProvider]的全部服务
  ServiceProvider buildScope({void Function(ServiceCollection)? builder, Object? scope}) {
    final scopedBuilder = ServiceCollection();
    builder?.call(scopedBuilder);
    return scopedBuilder.buildScopeServiceProvider(this);
  }

  /// 释放
  void dispose() {
    for (final element in _singletons.values) {
      if (element is DependencyInjectionService) {
        element.dispose();
      }
    }
    _singletons.clear();
  }
}