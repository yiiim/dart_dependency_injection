part of './dart_dependency_injection.dart';

extension ServiceObserviceListExtension on Iterable<ServiceObserver> {
  void onServiceCreated(service) {
    for (var element in this) {
      try {
        element.onServiceCreated(service);
      } catch (e, s) {
        // 捕获异常和堆栈信息
        assert(
          false,
          'ServiceObserver($runtimeType) ${element.runtimeType} onServiceCreated \n $e \n $s', // 在这里打印堆栈信息
        );
      }
    }
  }

  void onServiceInitializeDone(service) {
    for (var element in this) {
      try {
        element.onServiceInitializeDone(service);
      } catch (e, s) {
        // 捕获异常和堆栈信息
        assert(
          false,
          'ServiceObserver($runtimeType) ${element.runtimeType} onServiceInitializeDone \n $e \n $s', // 在这里打印堆栈信息
        );
      }
    }
  }

  void onServiceDispose(service) {
    for (var element in this) {
      try {
        element.onServiceDispose(service);
      } catch (e, s) {
        // 捕获异常和堆栈信息
        assert(
          false,
          'ServiceObserver($runtimeType) ${element.runtimeType} onServiceDispose \n $e \n $s', // 在这里打印堆栈信息
        );
      }
    }
  }
}

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
        _finalizer = !strongReference ? Finalizer<_ServiceBoundle>((t) => t.finalize()) : null {
    _finalizer?.attach(service, this, detach: service);
  }

  /// the service type
  final Type serviceType;

  /// the service definition
  final ServiceDescriptor serviceDefinition;

  /// the service of scope
  final ServiceProvider scoped;

  /// the scope provider created by this bundle
  late final List<ServiceProvider> scopedProvider = [];

  /// the service observers
  final List<ServiceObserver> observer;

  /// weak reference service
  ///
  /// boundle should not get the service when service is transient
  /// transient service can be cleared by Dart GC
  /// boundle uses _finalizer to call dispose when service is cleared by Dart GC
  final WeakReference<Object> _weakReferenceService;

  /// strong reference, keep single service alive
  ///
  /// if the service is transient, this reference will be null
  final Object? _strongReferenceService;

  /// the transient service finalizer
  ///
  /// if the service is transient, when the service is cleared by Dart GC, this finalizer will call dispose
  final Finalizer<_ServiceBoundle>? _finalizer;

  /// get service
  Object get service {
    assert(_weakReferenceService.target != null, 'service was disposed');
    return _strongReferenceService ?? _weakReferenceService.target!;
  }

  /// [Finalizer] will call this method when service is cleared by Dart GC
  void finalize() {
    dispose(disposeByFinalizer: true);
  }

  /// dispose service boundle
  ///
  /// [disposeByServiceProvider] dispose by service provider
  void dispose({bool disposeByServiceProvider = false, bool disposeByFinalizer = false}) {
    // dispose all the scoped provider these are created by this boundle
    for (var element in scopedProvider) {
      element.dispose();
    }

    // notify observer
    observer.onServiceDispose(_weakReferenceService.target);
    observer.clear();

    // if the service is alive and is [DependencyInjectionService], detach it from this boundle
    if (_weakReferenceService.target != null) {
      if (_weakReferenceService.target is DependencyInjectionService) {
        (_weakReferenceService.target as DependencyInjectionService)._detachFromBoundle(this);
      }
    }

    // if this boundle is not dispose by finalizer, detach from finalizer
    if (!disposeByFinalizer) {
      _finalizer?.detach(service);
    }

    // if this boundle is not dispose by service provider, maybe dispose by service itself or finalizer, remove it from service provider
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

/// this is the scope identifier when [DependencyInjectionService] build a scoped service provider
class _BuildFromServiceScope {
  _BuildFromServiceScope({
    required this.createByService,
    this.scope,
  });

  /// user scope identifier
  final Object? scope;

  /// the [_ServiceBoundle] that create this scope
  final _ServiceBoundle createByService;
}

/// ## ServiceProvider
///
/// The service provider, build from a [ServiceCollection]
///
/// The service can be gotten from this [ServiceProvider] if it is defined in the [ServiceCollection]
///
/// example:
///
/// ```dart
/// // create a service collection
/// var collection = ServiceCollection();
/// // define a service
/// collection.addSingleton<TestService>((serviceProvider) => TestService());
/// // build a service provider
/// var provider = collection.build();
/// // get service
/// var service = provider.get<TestService>();
/// ```
///
/// The [ServiceProvider] may also be one of the scopes of the parent [ServiceProvider]
/// The scope [ServiceProvider] will inherit all services of the parent [ServiceProvider]
///
/// example
/// ```dart
/// // ...
/// var provider = collection.build();
/// // build a scoped service provider
/// var scopedProvider = provider.buildScoped();
/// // get service from scoped service provider
/// var service = scopedProvider.get<TestService>();
/// ```
///
/// When building the scope [ServiceProvider], services defined by the parent can be overridden
///
/// example
/// ```dart
/// // ...
/// collection.addSingleton<TestService>((serviceProvider) => TestService());
/// var provider = collection.build();
/// // build a scoped service provider
/// var scopedProvider = provider.buildScoped(
///  builder: (collection) {
///     // override the service
///     collection.addSingleton<TestService>((serviceProvider) => MyTestService());
///   },
/// );
/// // get service from scoped service provider
/// var service = scopedProvider.get<TestService>();
/// // service is MyTestService
/// ```
class ServiceProvider {
  ServiceProvider._(
    Map<Type, ServiceDescriptor> serviceDescriptors, {
    this.parent,
    Object? scope,
  })  : serviceDescriptors = UnmodifiableMapView(serviceDescriptors),
        _scope = scope,
        _observerServiceDescriptor = serviceDescriptors.values.whereType<ServiceDescriptor<ServiceObserver>>().toList();

  final Object? _scope;
  Object? get scope {
    if (_scope is _BuildFromServiceScope) {
      return (_scope as _BuildFromServiceScope).scope;
    }
    return _scope;
  }

  /// the parent provider, if not null, this provider is a scope provider
  final ServiceProvider? parent;

  /// all of the service descriptors
  final Map<Type, ServiceDescriptor> serviceDescriptors;

  /// all the [Future] that currently executing [DependencyInjectionService.dependencyInjectionServiceInitialize]
  late final Map<Type, List<Future>> _asyncServiceInitializeProcessByType = {};

  /// [Future] of the latest service execution [DependencyInjectionService.dependencyInjectionServiceInitialize]
  Future? _latestServiceInitializeProcess;

  /// all the singletons in this provider
  late final Map<Type, _ServiceBoundle?> _singletons = {};

  /// all the scope singletons in this provider
  late final Map<Type, _ServiceBoundle?> _scopedSingletons = {};

  /// all the alive transient services in this provider
  late final Map<Type, List<_ServiceBoundle>> _transientServices = {};

  /// all the sub scope provider
  late final List<ServiceProvider> _scopeds = [];

  /// all the [ServiceDescriptor] of service observers
  final List<ServiceDescriptor<ServiceObserver>> _observerServiceDescriptor;

  @visibleForTesting
  Object? getExistSingleton(Type serviceType) {
    if (_singletons.containsKey(serviceType)) {
      return _singletons[serviceType];
    }
    return parent?.getExistSingleton(serviceType);
  }

  @visibleForTesting
  Object? getExistScopedSingleton(Type serviceType) {
    return _scopedSingletons[serviceType];
  }

  @visibleForTesting
  List<Object>? getExistTransient(Type serviceType) {
    return _transientServices[serviceType];
  }

  /// find the service observer from this provider
  ///
  /// observer for the [serviceDefinition]
  /// [dealScoped] the scope of the service
  Iterable<ServiceObserver> _getObservers(ServiceDescriptor serviceDefinition, ServiceProvider dealScoped) {
    assert(serviceDescriptors.values.contains(serviceDefinition));
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
      var observers = provider._observerServiceDescriptor.where(
        (element) {
          return element != serviceDefinition && (element.serviceType == ServiceObserver || serviceDefinition._isObserver(element));
        },
      ).map<ServiceObserver>(
        (e) => provider.__get(e, e.serviceType, dealScoped),
      );
      yield* observers;
      // find from parent
      if (provider != this && provider.parent != null) {
        yield* findObservers(provider.parent!);
      }
    }

    return findObservers(dealScoped);
  }

  late final List<ServiceDescriptor> _debugGettingServiceDefinition = [];

  /// get service with [ServiceDescriptor]
  dynamic __get(ServiceDescriptor serviceDefinition, Type serviceType, ServiceProvider dealScoped) {
    assert(serviceDescriptors.values.contains(serviceDefinition));
    // the service scope that for this service
    var serviceScope = serviceDefinition.isSingleton ? this : dealScoped;

    if (serviceDefinition.isSingleton) {
      assert(!_singletons.containsKey(serviceType) || _singletons[serviceType] != null, 'singleton service was disposed');
      _ServiceBoundle? singletonValue = serviceScope._singletons[serviceType];
      if (singletonValue != null) {
        if ((dealScoped._latestServiceInitializeProcess = _asyncServiceInitializeProcessByType[serviceType]?.firstOrNull) != null) {
          scheduleMicrotask(() => dealScoped._latestServiceInitializeProcess = null);
        }
        return singletonValue.service;
      }
    } else if (serviceDefinition.isScopeSingleton) {
      assert(!serviceScope._scopedSingletons.containsKey(serviceType) || serviceScope._scopedSingletons[serviceType] != null, 'scope singleton service was disposed');
      _ServiceBoundle? scopedSingletonValue = serviceScope._scopedSingletons[serviceType];
      if (scopedSingletonValue != null) {
        if ((dealScoped._latestServiceInitializeProcess = dealScoped._asyncServiceInitializeProcessByType[serviceType]?.firstOrNull) != null) {
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
      """You are getting services recursively for ${serviceDefinition.serviceType}！\n
      Including but not limited to the following situations：\n
      1. Get the service when you create it.\n
      2. Get the same service in the transient service dependencyInjectionServiceInitialize method.\n
      3. Get transient service in ServiceObserver \n""",
    );
    // create service
    late final service = serviceDefinition.factory(dealScoped);
    // configure service
    serviceDefinition._callConfiguration(service);
    // find observers
    var observers = _getObservers(serviceDefinition, dealScoped).toList();
    // create boundle
    var boundle = _ServiceBoundle(
      scoped: serviceScope,
      service: service,
      serviceDefinition: serviceDefinition,
      serviceType: serviceType,
      observer: observers,
      strongReference: serviceDefinition.isSingleton || serviceDefinition.isScopeSingleton,
    );
    // save the boundle
    if (serviceDefinition.isSingleton) {
      _singletons[serviceType] = boundle;
    } else if (serviceDefinition.isScopeSingleton) {
      serviceScope._scopedSingletons[serviceType] = boundle;
    } else {
      serviceScope._transientServices[serviceType] ??= [];
      serviceScope._transientServices[serviceType]!.add(boundle);
    }

    if (service is DependencyInjectionService) {
      // attach to boundle
      service._attachToBoundle(boundle);
      // notify observers
      observers.onServiceCreated(service);
      // run initialize
      var initResult = service._runInitialize();
      // If the service requires asynchronous initialization
      if (initResult is Future) {
        dealScoped._latestServiceInitializeProcess = initResult;
        scheduleMicrotask(() => dealScoped._latestServiceInitializeProcess = null);
        serviceScope._asyncServiceInitializeProcessByType[serviceType] ??= <Future>[];
        serviceScope._asyncServiceInitializeProcessByType[serviceType]!.add(initResult);
        initResult.then(
          (value) {
            serviceScope._asyncServiceInitializeProcessByType[serviceType]!.remove(initResult);
            if (serviceScope._asyncServiceInitializeProcessByType[serviceType]!.isEmpty) {
              serviceScope._asyncServiceInitializeProcessByType.remove(serviceType);
            }
            observers.onServiceInitializeDone(service);
          },
        );
      } else {
        observers.onServiceInitializeDone(service);
      }
    } else {
      // notify observers
      observers.onServiceCreated(service);
    }
    assert(() {
      _debugGettingServiceDefinition.remove(serviceDefinition);
      return true;
    }());
    return service;
  }

  dynamic _get(Type serviceType, {ServiceProvider? dealScoped}) {
    final serviceDefinition = serviceDescriptors[serviceType];
    if (serviceDefinition == null) {
      var service = parent?._get(serviceType, dealScoped: dealScoped ?? this);
      return service;
    }
    return __get(serviceDefinition, serviceType, dealScoped ?? this);
  }

  /// ## Get service from [ServiceProvider]
  ///
  /// When get service from [ServiceProvider]
  ///
  /// gotten service instance may be different depending on  how the service defined in [ServiceCollection]
  ///
  /// ### for singleton service
  ///
  /// always get the same instance in the [ServiceProvider] and its sub [ServiceProvider] if the service is not overridden
  ///
  /// example:
  /// ```dart
  /// // ...
  /// collection.addSingleton<TestService>((serviceProvider) => TestService());
  /// // build a service provider
  /// var provider = collection.build();
  /// // build a scoped service provider
  /// var scopedProvider = provider.buildScoped();
  /// // get service from parent service provider
  /// var service1 = provider.get<TestService>();
  /// var service2 = provider.get<TestService>();
  /// // get service from scoped service provider
  /// var service3 = scopedProvider.get<TestService>();
  /// var service4 = scopedProvider.get<TestService>();
  /// // service1, service2, service3, service4 all is the same instance
  /// ```
  ///
  /// ### for scope singleton service
  ///
  /// always get the same instance in the same [ServiceProvider]
  ///
  /// example:
  /// ```dart
  /// // ...
  /// collection.addScopedSingleton<TestService>((serviceProvider) => TestService());
  /// // build a service provider
  /// var provider = collection.build();
  /// // build a scoped service provider
  /// var scopedProvider = provider.buildScoped();
  /// // build another scoped service provider
  /// var scopedProvider2 = provider.buildScoped();
  /// // get service from parent service provider
  /// var service1 = provider.get<TestService>();
  /// var service2 = provider.get<TestService>();
  /// // get service from scoped service provider
  /// var service3 = scopedProvider.get<TestService>();
  /// var service4 = scopedProvider.get<TestService>();
  /// // get service from another scoped service provider
  /// var service5 = scopedProvider2.get<TestService>();
  /// var service6 = scopedProvider2.get<TestService>();
  /// // service1, service2 is the same instance
  /// // service3, service4 is the same instance
  /// // service5, service6 is the same instance
  /// ```
  ///
  /// ### for transient service
  ///
  /// always get a new instance
  ///
  /// example:
  /// ```dart
  /// // ...
  /// collection.add<TestService>((serviceProvider) => TestService());
  /// // build a service provider
  /// var provider = collection.build();
  /// // build a scoped service provider
  /// var scopedProvider = provider.buildScoped();
  /// // get service from parent service provider
  /// var service1 = provider.get<TestService>();
  /// var service2 = provider.get<TestService>();
  /// // get service from scoped service provider
  /// var service3 = scopedProvider.get<TestService>();
  /// var service4 = scopedProvider.get<TestService>();
  /// // service1, service2, service3, service4 all is different instance
  /// ```
  T get<T>() {
    var service = _get(T);
    if (service == null) {
      throw ServiceNotFoundException(
        'Service ${T.toString()} not found',
      );
    }
    return service;
  }

  /// try get service, if service not found, return null, see the [get] method
  T? tryGet<T>() => _get(T);

  /// get service by type, can see the [get] method
  dynamic getByType(Type type) {
    var service = _get(type);
    if (service == null) {
      throw ServiceNotFoundException(
        'Service ${type.toString()} not found',
      );
    }
    return service;
  }

  /// try get service by type, if service not found, return null, see the [get] method
  dynamic tryGetByType(Type type) => _get(type);

  /// find alive services
  Iterable<T> find<T>() => findByType(T).map((e) => e as T);

  /// find alive services by type, see the [find] method
  Iterable findByType(Type type) sync* {
    if (_transientServices.containsKey(type)) {
      yield* _transientServices[type]!.map((e) => e.service);
    }
    if (_scopedSingletons.containsKey(type)) {
      yield _scopedSingletons[type]!.service;
    }
    dynamic findSingleton(ServiceProvider provider) {
      if (provider._singletons.containsKey(type)) {
        return provider._singletons[type]!.service;
      }
      if (provider.parent != null) {
        return findSingleton(provider.parent!);
      }
    }

    var singleton = findSingleton(this);
    if (singleton != null) {
      yield singleton;
    }
  }

  /// Wait for the latest service to initialize
  FutureOr waitLatestServiceInitialize() => _latestServiceInitializeProcess;

  /// Wait for all current services to be initialized
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

  /// build a sub scope
  ///
  /// The scope [ServiceProvider] will inherit all services of the current [ServiceProvider]
  ServiceProvider buildScoped({void Function(ServiceCollection)? builder, Object? scope}) {
    final scopedBuilder = tryGet<ServiceCollection>() ?? ServiceCollection();
    builder?.call(scopedBuilder);
    return scopedBuilder.buildScoped(this, scope: scope);
  }

  /// dispose the [ServiceProvider]
  ///
  /// will dispose all the services and sub scopes
  void dispose() {
    // dispose singleton service
    for (final element in _singletons.keys) {
      _singletons[element]?.dispose(disposeByServiceProvider: true);
      _singletons[element] = null;
    }
    // dispose scope singleton service
    for (final element in _scopedSingletons.keys) {
      _scopedSingletons[element]?.dispose(disposeByServiceProvider: true);
      _scopedSingletons[element] = null;
    }
    // dispose transient service
    var transientServices = Map.of(_transientServices);
    _transientServices.clear();
    for (final element in transientServices.values) {
      for (final element2 in element) {
        element2.dispose(disposeByServiceProvider: true);
      }
    }
    if (_scope is _BuildFromServiceScope) {
      (_scope as _BuildFromServiceScope).createByService.scopedProvider.remove(this);
    }
    // dispose sub scope
    var scopes = List<ServiceProvider>.of(_scopeds);
    _scopeds.clear();
    for (var element in scopes) {
      element.dispose();
    }
    parent?._scopeds.remove(this);
  }
}
