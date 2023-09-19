# Dart Dependency Injection

This library is inspired by [ioc_container](https://github.com/MelbourneDeveloper/ioc_container), thanks to the author.

## Getting Started

Create a `ServiceCollection`:

```dart
var collection = ServiceCollection();
```

Add services to the `ServiceCollection`:

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
var provider = collection.build();
```

Get services from the `ServiceProvider`:

```dart
var testService = provider.get<TestService>();
```

## ServiceProvider

### Adding Services

create a ```ServiceCollection```:

```dart
var collection = ServiceCollection();
```

#### Add Singleton

```dart
collection.addSingleton<TestSingletonService>((serviceProvider) => TestSingletonService());
```

A singleton service has only one instance in the current scope as well as any derived scopes.

#### Add Scoped Singleton

```dart
collection.addScopedSingleton<TestScopedSingletonService>((serviceProvider) => TestScopedSingletonService());
```

A scoped singleton service gets a different instance for each scope it is requested from. Within the same scope, the service will always return the same instance.

#### Add Transient

```dart
collection.add<TestService>((serviceProvider) => TestService());
```

A transient service will create a new instance every time it is got.

### Build a ServiceProvider

```dart
var collection = ServiceCollection();
// ... add some services
var serviceProvider = ServiceProvider build();
```

After building the ServiceProvider, you will no longer be able to add services, but you can build the scope.


### Build a Scope ServiceProvider

```dart
var collection = ServiceCollection();
// ... add some services
var parentProvider = ServiceProvider build();
// build a scope
var scopedServiceProvider = parentProvider.buildScoped(
  builder: (collection) {
    // ... add some services
  },
);
```

Scoped service providers will inherit all services from the parent and additional services can be added

## Service

### Get service instance

```dart
TestService testService = provider.get<TestService>();
// or
TestService testService = provider.getByType(TestService);
```

Will throw an exception if the service does not exist

or

```dart
TestService? testService = provider.tryGet<TestService>();
// or
TestService? testService = provider.tryGetType(TestService);
```

Returns null if the service does not exist

### Service scope

for singleton service, its scope is always the one where it was defined.

for scoped singleton service, its scope is the one where it was created.

for transient service, its scope is the one where it was created.

## Service Initialization

If the injected service with the `DependencyInjectionService` and overrides the `dependencyInjectionServiceInitialize` method, that method will be executed immediately after creation.

Write the initialization code as follows:

```dart
class TestService with DependencyInjectionService {
  @override
  FutureOr dependencyInjectionServiceInitialize(){
    print("run at service create");
  }
}
```

The `dependencyInjectionServiceInitialize` method can be async, and two methods in the ServiceProvider can be used to wait for async initialization:

```dart
/// Wait for the most recently requested service to initialize. Must be called immediately after getting a service.
FutureOr waitLatestServiceInitialize();

/// Wait for all currently initializing services to finish.
FutureOr waitServicesInitialize();
```

### initializeWhenServiceProviderBuilt

there is a parameter `initializeWhenServiceProviderBuilt` when adding a service, if it is set to `true`, the service will be created once immediately after generating the `ServiceProvider` and then initialized.

some codes like this:

```dart
var collection = ServiceCollection();
collection.add<TestService>((serviceProvider) => TestService(), initializeWhenServiceProviderBuilt: true);
var provider = collection.build();
// TestService will be created once and initialized immediately
```

## ServiceObserver

`ServiceObserver` is an interface that can be implemented to observe the creation, initialization, and disposal of services.

```dart
abstract class ServiceObserver<T> {
  void onServiceCreated(T service);
  void onServiceInitializeDone(T service);
  void onServiceDispose(T service);
}
```

### Add observer for every services

```dart
var collection = ServiceCollection();
// ...add some services
collection.add<ServiceObserver>((serviceProvider) => TestServiceObserver());
```

When the service is created, a `ServiceObserver` service will be created to observer this service.

### Add observer for a service

```dart
var collection = ServiceCollection();
// ...add some services
collection.add<ServiceObserver<TestService>>((serviceProvider) => TestServiceObserver());
```

just only the `TestService` will be observed.

## DependencyInjectionService

`DependencyInjectionService` is a mixin that provides some magic methods for services created by dependency injection.

```dart
/// Get a service.
T getService<T extends Object>();

/// Try to get a service. Returns null if the service does not exist.
T? tryGetService<T extends Object>();

/// Get a service by type.
dynamic getServiceByType(Type type);

/// Try to get a service by type. Returns null if the service does not exist.
dynamic tryGetServiceByType(Type type);

/// Wait for the most recently requested service to initialize. Must be called immediately after getting a service.
FutureOr waitLatestServiceInitialize();

/// Wait for all currently initializing services to finish.
FutureOr waitServicesInitialize();

/// Create a scope
ServiceProvider buildScopedServiceProvider<T>({void Function(ServiceCollection)? builder, Object? scope});
```

Use these methods just like using the `ServiceProvider` in **your scope**.

### ServiceProvider Dispose

Call the dispose method of `ServiceProvider`. `ServiceProvider` also calls dispose for all alive services and all subscopes.

### Service Dispose

Any service can call the dispose method itself. After dispose, you will not be able to use any method of DependencyInjectionService. And the scope built using the buildScopedServiceProvider method of DependencyInjectionService will also dispose.

The service's dispose is usually called automatically :

for singleton service, Call dispose when defining its scope dispose.

for scoped singleton service, Call dispose when the scope is disposed.

for transient service :

If you don't use it anymore, it may be cleared by GC at any time.

When it is cleared by GC, the ServiceProvider built by its buildScopedServiceProvider method will call dispose.

If it is still alive, it will be called dispose when the ServiceProvider disposes it.
