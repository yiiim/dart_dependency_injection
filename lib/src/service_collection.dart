part of './dart_dependency_injection.dart';

/// The service collection
///
/// example:
/// ```dart
/// var collection = ServiceCollection();
/// // add a singleton service
/// collection.addSingleton((serviceProvider) => TestService());
/// // add a scoped service
/// collection.addScopedSingleton((serviceProvider) => TestService());
/// // add a transient service
/// collection.add((serviceProvider) => TestService());
/// // build service provider
/// var provider = collection.build();
/// ```
class ServiceCollection {
  ServiceCollection({this.allowOverrides = false});
  final Map<Type, ServiceDescriptor> _serviceDescriptor = {};
  final Map<Type, ServiceDescriptor> _initializeWhenProviderBuilt = {};

  /// allow overrides service,  default is false
  ///
  /// if false, can't add service with same types
  /// 
  /// example:
  /// ```dart
  /// var collection = ServiceCollection();
  /// // add a singleton service
  /// collection.addSingleton<TestService>((serviceProvider) => TestService());
  /// // add a singleton service with same type
  /// collection.addSingleton<TestService>((serviceProvider) => TestService());
  /// ```
  /// will throw [ServiceAlreadyExistsException]
  /// 
  /// but you can add same instance type with different service type
  /// ```dart
  /// var collection = ServiceCollection();
  /// // add a singleton service
  /// collection.addSingleton<TestService>((serviceProvider) => TestService());
  /// // add a singleton service with same type
  /// collection.addSingleton<ITestService>((serviceProvider) => TestService());
  /// ```
  /// 
  /// ---
  /// 
  /// if true, can add service with same types, the last one will override the previous one
  final bool allowOverrides;

  /// add a service with [ServiceDescriptor]
  ///
  /// [serviceDescriptor] the service descriptor
  /// [initializeWhenServiceProviderBuilt] whether to initialize immediately after build [ServiceProvider]
  void addServiceDescriptor<T>(ServiceDescriptor<T> serviceDescriptor, {bool initializeWhenServiceProviderBuilt = false}) {
    if (_serviceDescriptor.containsKey(T)) {
      if (allowOverrides) {
        _serviceDescriptor.remove(T);
      } else {
        throw ServiceAlreadyExistsException('$T Service already exists');
      }
    }

    _serviceDescriptor.putIfAbsent(T, () => serviceDescriptor);
    _initializeWhenProviderBuilt.remove(T);
    if (initializeWhenServiceProviderBuilt) {
      _initializeWhenProviderBuilt[T] = serviceDescriptor;
    }
  }

  /// add a singleton service
  ///
  /// [factory] the service factory
  /// [initializeWhenServiceProviderBuilt] whether to creationg the service immediately after build [ServiceProvider]
  void addSingleton<T>(T Function(ServiceProvider serviceProvider) factory, {bool initializeWhenServiceProviderBuilt = false}) {
    addServiceDescriptor<T>(ServiceDescriptor<T>((serviceProvider) => factory(serviceProvider), isSingleton: true), initializeWhenServiceProviderBuilt: initializeWhenServiceProviderBuilt);
  }

  /// add a scoped service
  ///
  /// [factory] the service factory
  /// [initializeWhenServiceProviderBuilt] whether to creationg the service immediately after build [ServiceProvider]
  void addScopedSingleton<T>(T Function(ServiceProvider serviceProvider) factory, {bool initializeWhenServiceProviderBuilt = false}) => addServiceDescriptor<T>(
        ServiceDescriptor<T>(
          (serviceProvider) => factory(serviceProvider),
          isScopeSingleton: true,
        ),
        initializeWhenServiceProviderBuilt: initializeWhenServiceProviderBuilt,
      );

  /// add a transient service
  ///
  /// [factory] the service factory
  /// [initializeWhenServiceProviderBuilt] whether to creationg the service immediately after build [ServiceProvider]
  void add<T>(T Function(ServiceProvider serviceProvider) factory, {bool initializeWhenServiceProviderBuilt = false}) => addServiceDescriptor<T>(
        ServiceDescriptor<T>(
          (serviceProvider) => factory(serviceProvider),
        ),
        initializeWhenServiceProviderBuilt: initializeWhenServiceProviderBuilt,
      );

  /// build a scoped service provider from parent service provider
  ///
  /// [parent] the parent service provider.
  /// 
  /// The built [ServiceProvider] will get all the services of parent
  /// 
  /// if has same service type in self with parent, will override parent
  /// 
  /// [scope] the scope identifier, no special meaning
  /// 
  /// if [initializeWhenServiceProviderBuilt] be set to true when add service, will creationg the service immediately after build [ServiceProvider]
  ServiceProvider buildScoped(ServiceProvider parent, {Object? scope}) {
    var provider = ServiceProvider._(
      Map<Type, ServiceDescriptor>.unmodifiable(
        _serviceDescriptor,
      ),
      parent: parent,
      scope: scope,
    );
    parent._scopeds.add(provider);
    for (var element in _initializeWhenProviderBuilt.keys) {
      provider.__get(_initializeWhenProviderBuilt[element]!, element, provider);
    }
    return provider;
  }

  /// build a [ServiceProvider]
  /// 
  /// The built [ServiceProvider] can with the service type `get` all added services 
  /// 
  /// if [initializeWhenServiceProviderBuilt] be set to true when add service, will creationg the service immediately after build [ServiceProvider]
  ServiceProvider build() {
    var provider = ServiceProvider._(
      Map<Type, ServiceDescriptor>.unmodifiable(
        _serviceDescriptor,
      ),
    );
    for (var element in _initializeWhenProviderBuilt.keys) {
      provider.__get(_initializeWhenProviderBuilt[element]!, element, provider);
    }
    return provider;
  }
}
