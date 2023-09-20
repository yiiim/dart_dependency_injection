part of './dart_dependency_injection.dart';

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

/// 服务捆绑包
class _ServiceBoundle {
  _ServiceBoundle({
    required this.serviceType,
    required this.serviceDefinition,
    required this.scoped,
    required this.observer,
    required Object service,
    bool strongReference = false,
  })  : _weakReferenceService = WeakReference(service),
        _strongReferenceService = strongReference == true ? service : null,
        _finalizer = !strongReference ? Finalizer<_ServiceBoundle>((t) => t.dispose()) : null {
    _finalizer?.attach(service, this);
  }

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

  /// 弱引用服务，如果服务被释放，这个引用将为null，释放时由[_finalizer]执行dispose
  final WeakReference<Object> _weakReferenceService;

  /// 强引用的服务,不使用这个属性，只是作为单例的强引用，避免释放，应使用[_weakReferenceService]
  // ignore: unused_field
  final Object? _strongReferenceService;

  /// 释放器
  final Finalizer<_ServiceBoundle>? _finalizer;

  /// 服务
  Object get service {
    assert(_weakReferenceService.target != null, 'service was disposed');
    return _weakReferenceService.target!;
  }

  /// 释放服务包
  void dispose({bool disposeByServiceProvider = false}) {
    // 释放从这个捆绑包中生成的范围
    for (var element in scopedProvider) {
      element.dispose();
    }
    // 执行观察者
    for (var element in observer) {
      element.onServiceDispose(_weakReferenceService.target);
    }
    // 如果服务自己还没被释放
    if (_weakReferenceService.target != null) {
      // 如果服务是 [DependencyInjectionService]类型，将服务从捆绑包中分离
      if (_weakReferenceService.target is DependencyInjectionService) {
        (_weakReferenceService.target as DependencyInjectionService)._detachFromBoundle(this);
      }
    }
    // 从所属范围中移除，如果当前服务是在范围释放时释放的，通常不需要这么做
    // 但是如果服务是自主释放的，则需要从范围中移除
    if (!disposeByServiceProvider) {
      if (serviceDefinition.isSingleton) {
        scoped._singletons[serviceType] = null;
      } else if (serviceDefinition.isScopeSingleton) {
        scoped._scopedSingletons[serviceType] = null;
      } else {
        if (scoped._transientServices.isNotEmpty) {
          assert(scoped._transientServices[serviceType]!.contains(this));
          var transientServices = scoped._transientServices[serviceType];
          transientServices?.remove(this);
          if (transientServices?.isEmpty == true) {
            scoped._transientServices.remove(serviceType);
          }
        }
      }
    }
  }
}

/// 该标签表示这个范围是从某一个服务生成的
class _BuildFromServiceScope {
  _BuildFromServiceScope({
    required this.createByService,
    this.scope,
  });
  final Object? scope;
  final _ServiceBoundle createByService;
}

/// 服务提供器
class ServiceProvider {
  ServiceProvider._(
    Map<Type, ServiceDescriptor> serviceDescriptors, {
    this.parent,
    Object? scope,
  })  : _serviceDescriptors = serviceDescriptors,
        _scope = scope,
        _observerServiceDescriptor = serviceDescriptors.values.whereType<ServiceDescriptor<ServiceObserver>>().toList();

  /// 范围标签
  final Object? _scope;
  Object? get scope {
    if (_scope is _BuildFromServiceScope) {
      return (_scope as _BuildFromServiceScope).scope;
    }
    return _scope;
  }

  /// 父级，如果不是空，表示这个是一个范围
  final ServiceProvider? parent;

  /// 全部的服务描述
  final Map<Type, ServiceDescriptor> _serviceDescriptors;

  /// [ServiceProvider]中当前正在执行[DependencyInjectionService.dependencyInjectionServiceInitialize]的[Future]
  late final Map<Type, List<Future>> _asyncServiceInitializeProcessByType = {};

  /// [ServiceProvider]最近一个服务执行[DependencyInjectionService.dependencyInjectionServiceInitialize] 的[Future]
  Future? _latestServiceInitializeProcess;

  /// 存储的单例
  late final Map<Type, _ServiceBoundle?> _singletons = {};

  /// 存储的范围单例
  late final Map<Type, _ServiceBoundle?> _scopedSingletons = {};

  /// 储存的普通服务
  late final Map<Type, List<_ServiceBoundle>> _transientServices = {};

  /// 生成的子范围
  late final List<ServiceProvider> _scopeds = [];

  /// 全部的观察者服务
  final List<ServiceDescriptor<ServiceObserver>> _observerServiceDescriptor;

  /// 供单元测试用，获取已经存在的单例
  @visibleForTesting
  Object? getExistSingleton(Type serviceType) {
    if (_singletons.containsKey(serviceType)) {
      return _singletons[serviceType];
    }
    return parent?.getExistSingleton(serviceType);
  }

  /// 供单元测试用，获取已经存在的范围单例
  @visibleForTesting
  Object? getExistScopedSingleton(Type serviceType) {
    return _scopedSingletons[serviceType];
  }

  /// 供单元测试用，获取已经存在的普通服务
  @visibleForTesting
  List<Object>? getExistTransient(Type serviceType) {
    return _transientServices[serviceType];
  }

  /// 找到服务的观察者
  ///
  /// [serviceDefinition]服务定义
  /// [dealScoped]获取服务的范围
  Iterable<ServiceObserver> _getObservers(ServiceDescriptor serviceDefinition, ServiceProvider dealScoped) {
    assert(_serviceDescriptors.values.contains(serviceDefinition));
    assert(() {
      ServiceProvider? childProvider = dealScoped;
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
          return element != serviceDefinition && (element.serviceType == ServiceObserver || serviceDefinition.isObserver(element));
        },
      ).map<ServiceObserver>(
        (e) => __get(e, e.serviceType, dealScoped),
      );
      yield* observers;
      // 如果provider不是当前provider，继续向上查找
      // 不需要在当前provider的父级中找观察者，父级注入的观察者不应观察子级注入的服务
      if (provider != this && provider.parent != null) {
        yield* findObservers(provider.parent!);
      }
    }

    return findObservers(dealScoped);
  }

  late final List<ServiceDescriptor> _debugGettingServiceDefinition = [];

  /// 根据[ServiceDescriptor]获取服务
  ///
  /// [ServiceDescriptor]服务描述
  /// [serviceType]服务类型
  /// [dealScoped]获取服务的范围
  dynamic __get(ServiceDescriptor serviceDefinition, Type serviceType, ServiceProvider dealScoped) {
    assert(_serviceDescriptors.values.contains(serviceDefinition));
    // 服务所属的范围
    var serviceScope = serviceDefinition.isSingleton ? this : dealScoped;

    if /*如果是单例*/ (serviceDefinition.isSingleton) {
      assert(!_singletons.containsKey(serviceType) || _singletons[serviceType] != null, 'singleton service was disposed');
      _ServiceBoundle? singletonValue = serviceScope._singletons[serviceType];
      if (singletonValue != null) {
        if /*如果这个服务还在初始化*/ ((dealScoped._latestServiceInitializeProcess = _asyncServiceInitializeProcessByType[serviceType]?.firstOrNull) != null) {
          scheduleMicrotask(() => dealScoped._latestServiceInitializeProcess = null);
        }
        return singletonValue.service;
      }
    } else if /*如果是范围单例*/ (serviceDefinition.isScopeSingleton) {
      assert(!serviceScope._scopedSingletons.containsKey(serviceType) || serviceScope._scopedSingletons[serviceType] != null, 'scope singleton service was disposed');
      _ServiceBoundle? scopedSingletonValue = serviceScope._scopedSingletons[serviceType];
      if (scopedSingletonValue != null) {
        if /*如果这个服务还在初始化*/ ((dealScoped._latestServiceInitializeProcess = dealScoped._asyncServiceInitializeProcessByType[serviceType]?.firstOrNull) != null) {
          scheduleMicrotask(() => dealScoped._latestServiceInitializeProcess = null);
        }
        return scopedSingletonValue.service;
      }
    }

    assert(
      () {
        if (_debugGettingServiceDefinition.contains(serviceDefinition)) {
          return false;
        }
        _debugGettingServiceDefinition.add(serviceDefinition);
        return true;
      }(),
      """You are getting services recursively！\n
      Including but not limited to the following situations：\n
      1. Get the service when you create it.\n
      2. Get the same service in the transient service dependencyInjectionServiceInitialize method.\n
      3. Get transient service in ServiceObserver \n""",
    );

    // 如果没有找到单例，则需要创建服务
    // 创建服务
    final service = serviceDefinition.factory(dealScoped);
    // 找到观察者
    var observers = _getObservers(serviceDefinition, dealScoped).toList();
    // boundle
    var boundle = _ServiceBoundle(
      scoped: serviceScope,
      service: service,
      serviceDefinition: serviceDefinition,
      serviceType: serviceType,
      observer: observers,
      strongReference: serviceDefinition.isSingleton || serviceDefinition.isScopeSingleton,
    );
    // 先保存服务
    if /*如果是单例，保存到自己的单例*/ (serviceDefinition.isSingleton) {
      _singletons[serviceType] = boundle;
    } else if /*如果是范围单例，保存到获取服务的范围的单例中*/ (serviceDefinition.isScopeSingleton) {
      serviceScope._scopedSingletons[serviceType] = boundle;
    } else /*普通服务保存到获取服务的范围中*/ {
      serviceScope._transientServices[serviceType] ??= [];
      serviceScope._transientServices[serviceType]!.add(boundle);
    }

    // 执行观察者
    observers.onServiceCreated(service);
    // 如果服务是 [DependencyInjectionService]类型
    if (service is DependencyInjectionService) {
      // 设置服务的boundle, 初始化服务
      var initResult = service._attachToBoundle(boundle);
      // 如果是异步初始化
      if (initResult is Future) {
        // 设置最近的异步future，这里需要是dealScoped，因为dealScoped是获取服务的范围，用户在等待最近的服务初始化时也是使用的dealScoped
        dealScoped._latestServiceInitializeProcess = initResult;
        // 仅在获取服务后立即等待最近的异步future有效
        scheduleMicrotask(() => dealScoped._latestServiceInitializeProcess = null);
        // 保存异步future
        serviceScope._asyncServiceInitializeProcessByType[serviceType] ??= <Future>[];
        serviceScope._asyncServiceInitializeProcessByType[serviceType]!.add(initResult);
        // 异步初始化结束后
        initResult.then(
          (value) {
            // 移除保存的future
            serviceScope._asyncServiceInitializeProcessByType[serviceType]!.remove(initResult);
            if (serviceScope._asyncServiceInitializeProcessByType[serviceType]!.isEmpty) {
              serviceScope._asyncServiceInitializeProcessByType.remove(serviceType);
            }
            // 执行观察者
            observers.onServiceInitializeDone(service);
          },
        );
      } else {
        observers.onServiceInitializeDone(service);
      }
    }
    assert(() {
      _debugGettingServiceDefinition.remove(serviceDefinition);
      return true;
    }());
    return service;
  }

  /// 获取服务
  ///
  /// [dealScoped]获取服务的范围
  dynamic _get(Type serviceType, {ServiceProvider? dealScoped}) {
    final serviceDefinition = _serviceDescriptors[serviceType];
    if (serviceDefinition == null) {
      var service = parent?._get(serviceType, dealScoped: dealScoped ?? this);
      return service;
    }
    return __get(serviceDefinition, serviceType, dealScoped ?? this);
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
      if (parentWait is Future) parentWait,
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
    return scopedBuilder.buildScoped(this, scope: scope);
  }

  /// 释放
  void dispose() {
    // 释放单例
    for (final element in _singletons.keys) {
      _singletons[element]?.dispose(disposeByServiceProvider: true);
      _singletons[element] = null;
    }
    // 释放范围单例
    for (final element in _scopedSingletons.keys) {
      _scopedSingletons[element]?.dispose(disposeByServiceProvider: true);
      _scopedSingletons[element] = null;
    }
    // 释放普通服务
    var transientServices = Map.of(_transientServices);
    _transientServices.clear();
    for (final element in transientServices.values) {
      for (final element2 in element) {
        element2.dispose(disposeByServiceProvider: true);
      }
    }
    // 如果是从某一个服务生成的范围，从服务中移除
    if (_scope is _BuildFromServiceScope) {
      (_scope as _BuildFromServiceScope).createByService.scopedProvider.remove(this);
    }
    // 释放子范围
    var scopes = List<ServiceProvider>.of(_scopeds);
    _scopeds.clear();
    for (var element in scopes) {
      element.dispose();
    }
    // 从父级移除
    parent?._scopeds.remove(this);
  }
}
