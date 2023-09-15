part of './dart_dependency_injection.dart';

class _ServiceBoundle {
  _ServiceBoundle({
    required this.serviceType,
    required this.serviceDefinition,
    required this.scoped,
    required this.service,
    required this.observer,
  });

  /// 服务类型
  final Type serviceType;

  /// 服务定义
  final ServiceDescriptor serviceDefinition;

  /// 服务所属的范围
  final ServiceProvider scoped;

  /// 从这个服务生成的范围
  late final List<ServiceProvider> scopedProvider = [];

  /// 服务观察者
  final List<ServiceObserver> observer;

  /// 服务
  final Object service;

  /// 服务初始化的[Future]
  FutureOr? _serviceInitializeFuture;

  void dispose() {
    for (var element in scopedProvider) {
      element.dispose();
    }
    if (service is DependencyInjectionService) {
      (service as DependencyInjectionService)._dependencyInjectionServiceDispose();
    }
    for (var element in observer) {
      element.onServiceDispose(service);
    }
  }
}

extension ServiceObserviceListExtension on Iterable<ServiceObserver> {
  void onServiceCreated(service) {
    for (var element in this) {
      element.onServiceCreated(service);
    }
  }

  void onServiceInitializeDone(service) {
    for (var element in this) {
      element.onServiceInitializeDone(service);
    }
  }

  void onServiceDispose(service) {
    for (var element in this) {
      element.onServiceDispose(service);
    }
  }
}

/// 服务提供器
class ServiceProvider {
  ServiceProvider(
    this._serviceDescriptors, {
    this.parent,
    this.scope,
  }) : _observerServiceDescriptor = _serviceDescriptors.values.whereType<ServiceDescriptor<ServiceObserver>>().toList();

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
  final Map<Type, _ServiceBoundle> _singletons = {};

  /// 生成的子范围
  final List<ServiceProvider> _scopeds = [];

  final List<ServiceDescriptor<ServiceObserver>> _observerServiceDescriptor;

  /// 是否有观察者，如果没有观察者，就不需要查找观察者服务，提高性能
  late final bool _hasObserver;

  /// 找到服务的观察者
  ///
  /// [serviceDefinition]服务定义
  /// [originalProvider]获取服务的provider
  Iterable<ServiceObserver> _getObservers(ServiceDescriptor serviceDefinition, {ServiceProvider? originalProvider}) {
    assert(_serviceDescriptors.values.contains(serviceDefinition));
    assert(() {
      ServiceProvider? childProvider = originalProvider ?? this;
      while (childProvider != null) {
        if (childProvider == this) {
          return true;
        }
        childProvider = childProvider.parent;
      }
      return false;
    }());
    Iterable<ServiceObserver> findObservers(ServiceProvider provider) sync* {
      // 找到provider中定义的观察者
      var observers = provider._observerServiceDescriptor.where(
        (element) {
          return element.isObserver(serviceDefinition);
        },
      ).map<ServiceObserver>(
        (e) => __get(serviceDefinition, e.serviceType),
      );
      yield* observers;
      // 如果provider不是当前provider，继续向上查找
      // 不需要在当前provider的父级中找观察者，父级注入的观察者不应观察子级注入的服务
      if (provider != this && provider.parent != null) {
        yield* findObservers(provider.parent!);
      }
    }

    return findObservers(originalProvider ?? this);
  }

  /// 根据[ServiceDescriptor]获取服务
  ///
  /// [ServiceDescriptor]服务描述
  /// [serviceType]服务类型
  /// [originalProvider]如果是从子级执行的，这个是最开始的子级
  dynamic __get(ServiceDescriptor serviceDefinition, Type serviceType, {ServiceProvider? originalProvider}) {
    assert(_serviceDescriptors.values.contains(serviceDefinition));

    // 如果是单例
    if (serviceDefinition.isSingleton) {
      final singletonValue = _singletons[serviceType];
      if (singletonValue != null) {
        // 如果这个服务还在初始化
        _latestServiceInitializeProcess = _asyncServiceInitializeProcessByType[serviceType]?.firstOrNull;
        scheduleMicrotask(() => _latestServiceInitializeProcess = null);
        return singletonValue.service;
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
        return singletonValue.service;
      }
    }

    // 如果没有找到单例，则需要创建服务
    // 服务所属的[ServiceProvider]为originalProvider，originalProvider为null就是this
    var provider = originalProvider ?? this;
    // 创建服务
    final service = serviceDefinition.factory(provider);
    // 观察者
    var observers = _getObservers(serviceDefinition, originalProvider: originalProvider).toList();
    // boundle
    var boundle = _ServiceBoundle(
      scoped: serviceDefinition.isSingleton ? this : provider,
      service: service,
      serviceDefinition: serviceDefinition,
      serviceType: serviceType,
      observer: observers,
    );
    // 执行观察者
    observers.onServiceCreated(service);
    // 如果服务是 [DependencyInjectionService]类型
    if (service is DependencyInjectionService) {
      // 设置服务的boundle
      service._attachToBoundle(boundle);
      // 初始化服务
      var initResult = (boundle._serviceInitializeFuture ??= service._dependencyInjectionServiceInitialize());
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
            boundle._serviceInitializeFuture = null;
            // 执行观察者
            observers.onServiceInitializeDone(service);
          },
        );
      } else {
        observers.onServiceInitializeDone(service);
      }
    } else {
      observers.onServiceInitializeDone(service);
    }

    if /*如果是单例，保存到单例*/ (serviceDefinition.isSingleton) {
      _singletons[serviceType] = boundle;
      service;
    } else if /*如果是范围单例，保存到所属的[ServiceProvider]单例*/ (serviceDefinition.isScopeSingleton) {
      provider._singletons[serviceType] = boundle;
    } else {
      Future(() => boundle.dispose());
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
  ServiceProvider buildScoped({void Function(ServiceCollection)? builder, Object? scope, _ServiceBoundle? boundle}) {
    final scopedBuilder = tryGet<ServiceCollection>() ?? ServiceCollection();
    builder?.call(scopedBuilder);
    var serviceProvider = scopedBuilder.buildScoped(this, scope: scope);
    if (boundle != null) {
      boundle.scopedProvider.add(serviceProvider);
    }
    return serviceProvider;
  }

  /// 释放
  void dispose() {
    // 释放单例
    var singletons = Map.of(_singletons);
    _singletons.clear();
    for (final element in singletons.values) {
      element.dispose();
    }
    // 释放范围
    var scopes = List<ServiceProvider>.of(_scopeds);
    _scopeds.clear();
    for (var element in scopes) {
      element.dispose();
    }
    // 从父级移除
    parent?._scopeds.remove(this);
  }
}
