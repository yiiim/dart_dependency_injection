# Dart Dependency Injection

This library is inspired by [ioc_container](https://github.com/MelbourneDeveloper/ioc_container), thanks to the author.

Language: English | [中文](https://github.com/yiiim/dart_dependency_injection/blob/master/README-zh.md)

- [Getting Started](#getting-started)
- [ServiceCollection](#servicecollection)
  - [Service Definition](#service-definition)
  - [Adding Services](#adding-services)
    - [Add Singleton](#add-singleton)
    - [Add Scoped Singleton](#add-scoped-singleton)
    - [Add Transient](#add-transient)
  - [Building a ServiceProvider](#building-a-serviceprovider)
- [ServiceProvider](#serviceprovider)
  - [Getting Services](#getting-services)
  - [Service Initialization](#service-initialization)
  - [Scopes](#scopes)
- [DependencyInjectionService](#dependencyinjectionservice)

## Getting Started

Create a service collection:

```dart
var collection = ServiceCollection();
```

Add services to the service collection:

```dart
// Add a transient service:
collection.add<TestService>((serviceProvider) => TestService());

// Add a singleton service:
collection.addSingleton<TestSingletonService>((serviceProvider) => TestSingletonService());

// Add a scoped singleton service:
collection.addScopedSingleton<TestScopedSingletonService>((serviceProvider) => TestScopedSingletonService());
```

Build a `ServiceProvider`:

```dart
var provider = collection.buildServiceProvider();
```

Get services from the `ServiceProvider`:

```dart
var testService = provider.get<TestService>();
```

## ServiceCollection

`ServiceCollection` represents a collection of services and contains all of the service definitions.

### Service Definition

A service definition has the following properties:

```dart
/// Whether this service is a singleton
final bool isSingleton;

/// Whether this service is a scoped singleton
final bool isScopeSingleton;

/// The factory method used to create the service
final T Function(ServiceProvider container) factory;
```

### Adding Services

To add services to a `ServiceCollection`, use the following methods:

#### Add Singleton

```dart
void addSingleton<T>(T Function(ServiceProvider serviceProvider) factory, {bool initializeWhenServiceProviderBuilt = false});
```

A singleton service has only one instance in the current scope as well as any derived scopes.

#### Add Scoped Singleton

```dart
void addScopedSingleton<T>(T Function(ServiceProvider serviceProvider) factory, {bool initializeWhenServiceProviderBuilt = false});
```

A scoped singleton service gets a different instance for each scope it is requested from. Within the same scope, the service will always return the same instance.

#### Add Transient

```dart
void add<T>(T Function(ServiceProvider serviceProvider) factory, {bool initializeWhenServiceProviderBuilt = false})
```

A transient service will create a new instance every time it is requested.

---

The `initializeWhenServiceProviderBuilt` parameter in the above methods represents whether to immediately initialize services after building a `ServiceProvider`.

### Building a ServiceProvider

Build a top-level `ServiceProvider`:

```dart
ServiceProvider buildServiceProvider();
```

---

Build a scoped `ServiceProvider`:

```dart
ServiceProvider buildScopedServiceProvider(ServiceProvider parent, {Object? scope});
```

The `parent` parameter represents the parent of this scoped `ServiceProvider`.

## ServiceProvider

`ServiceProvider` represents a service provider and is generated by `ServiceCollection`.

### Getting Services

```dart
/// Get a service of type T. Throws an exception if the service is not defined.
T get<T extends Object>();

/// Try to get a service of type T. Returns null if the service is not defined.
T? tryGet<T extends Object>();

/// Get a service of the specified type. Throws an exception if the service is not defined.
dynamic getByType(Type type);

/// Try to get a service of the specified type. Returns null if the service is not defined.
dynamic tryGetByType(Type type)
```

To get a service added by `ServiceCollection`, the type must match the generic type used when adding the service.

### Service Initialization

If a service needs to be created when getting the service, it will be initialized immediately after creation.

If the injected service mixes in `DependencyInjectionService` and overrides the `dependencyInjectionServiceInitialize` method, that method will be executed immediately after creation.

If the `initializeWhenServiceProviderBuilt` parameter was set to `true` when adding the service, the service will be created once immediately after generating the `ServiceProvider` and then initialized.

Write the initialization code as follows:

```dart
class TestService with DependencyInjectionService {
  @override
  FutureOr dependencyInjectionServiceInitialize(){
    print("run at service create");
  }
}
```

The `dependencyInjectionServiceInitialize` method can be async, and the following two methods can be used to wait for async initialization:

```dart
/// Wait for the most recently requested service to initialize. Must be called immediately after getting a service.
FutureOr waitLatestServiceInitialize();

/// Wait for all currently initializing services to finish.
FutureOr waitServicesInitialize();
```

### Scopes

You can derive a scope from the current `ServiceProvider` using the following method:

```dart
ServiceProvider buildScope({void Function(ServiceCollection)? builder, Object? scope});
```

Usage is as follows:

```dart
var testService = provider.get<TestService>();
var scopedServiceProvider = testService.buildScope(
    builder: (collection) {
        collection.add<TestService>((serviceProvider) => TestService());
    },
);
```

The derived scope inherits all of its parent's services and can add additional services within the new scope through the `builder` parameter. When getting a service from the new scope, if it is a parent singleton service, the same instance as the parent will be used. If it is a parent scoped singleton service, a new instance will be created within this scope.

If a scope is created, the `dispose` method must be called when it is no longer in use to release any singleton or scoped singleton services within that scope.

## DependencyInjectionService

`DependencyInjectionService` is a mixin that provides some magic methods for services created by dependency injection.

```dart
/// Get a service.
T getService<T extends Object>() => serviceProvider.get<T>();

/// Try to get a service. Returns null if the service does not exist.
T? tryGetService<T extends Object>() => serviceProvider.tryGet<T>();

/// Get a service by type.
dynamic getServiceByType(Type type) => serviceProvider.getByType(type);

/// Try to get a service by type. Returns null if the service does not exist.
dynamic tryGetServiceByType(Type type) => serviceProvider.tryGetByType(type);
```

These methods allow you to **get other dependency-injected services within a service created by dependency injection** just like with `ServiceProvider`.

---

Create a service scope:

```dart
ServiceProvider buildScopedServiceProvider<T>({void Function(ServiceCollection)? builder, Object? scope});
```

This method creates a service scope just like `ServiceProvider`, but you don't have to worry about calling `dispose` on the scope because it will automatically be called when the current service is disposed.

---

Wait for service initialization:

```dart
FutureOr waitLatestServiceInitialize() => serviceProvider.waitLatestServiceInitialize();
FutureOr waitServicesInitialize() => serviceProvider.waitServicesInitialize();
```

These methods are also from `ServiceProvider`, and allow you to wait for async-initialized services after getting them.

---

Since these methods all come from `ServiceProvider`, **you need to pay special attention to the scope of the current service** when using them.

1. If the current service is a singleton, its scope is always the one where it was defined.

2. If the current service is a transient or scoped singleton service, its scope is the one where it was created.
