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

  /// the service type
  final Type serviceType;

  /// the service definition
  final ServiceDescriptor serviceDefinition;

  /// the service scoped
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

  /// dispose service boundle
  ///
  /// [disposeByServiceProvider] dispose by service provider
  void dispose({bool disposeByServiceProvider = false}) {
    /// dispose all the scoped provider created by this boundle
    for (var element in scopedProvider) {
      element.dispose();
    }

    /// observer
    for (var element in observer) {
      element.onServiceDispose(_weakReferenceService.target);
    }
    observer.clear();

    /// if the service is alive and is [DependencyInjectionService], detach it from this boundle
    if (_weakReferenceService.target != null) {
      if (_weakReferenceService.target is DependencyInjectionService) {
        (_weakReferenceService.target as DependencyInjectionService)._detachFromBoundle(this);
      }
    }
    // if this boundle is not dispose by service provider, maybe dispose by service itself, remove it from service provider
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

class ServiceProvider {
  ServiceProvider._(
    Map<Type, ServiceDescriptor> serviceDescriptors, {
    this.parent,
    Object? scope,
  })  : _serviceDescriptors = serviceDescriptors,
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

  /// all the service descriptors
  final Map<Type, ServiceDescriptor> _serviceDescriptors;

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
      var observers = provider._observerServiceDescriptor.where(
        (element) {
          return element != serviceDefinition && (element.serviceType == ServiceObserver || serviceDefinition._isObserver(element));
        },
      ).map<ServiceObserver>(
        (e) => __get(e, e.serviceType, dealScoped),
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
    assert(_serviceDescriptors.values.contains(serviceDefinition));
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
      """You are getting services recursively！\n
      Including but not limited to the following situations：\n
      1. Get the service when you create it.\n
      2. Get the same service in the transient service dependencyInjectionServiceInitialize method.\n
      3. Get transient service in ServiceObserver \n""",
    );
    // create service
    final service = serviceDefinition.factory(dealScoped);
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
    // notify observers
    observers.onServiceCreated(service);
    if (service is DependencyInjectionService) {
      // attach to boundle
      var initResult = service._attachToBoundle(boundle);
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
    }
    assert(() {
      _debugGettingServiceDefinition.remove(serviceDefinition);
      return true;
    }());
    return service;
  }

  dynamic _get(Type serviceType, {ServiceProvider? dealScoped}) {
    final serviceDefinition = _serviceDescriptors[serviceType];
    if (serviceDefinition == null) {
      var service = parent?._get(serviceType, dealScoped: dealScoped ?? this);
      return service;
    }
    return __get(serviceDefinition, serviceType, dealScoped ?? this);
  }

  T get<T extends Object>() {
    var service = _get(T);
    if (service == null) {
      throw ServiceNotFoundException(
        'Service ${T.toString()} not found',
      );
    }
    return service;
  }

  T? tryGet<T extends Object>() => _get(T);

  dynamic getByType(Type type) {
    var service = _get(type);
    if (service == null) {
      throw ServiceNotFoundException(
        'Service ${type.toString()} not found',
      );
    }
    return service;
  }

  dynamic tryGetByType(Type type) => _get(type);

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
