
# Dart Dependency Injection

This library takes inspiration from [ioc_container](https://github.com/MelbourneDeveloper/ioc_container)，Thanks to the author

语言: [English](https://github.com/yiiim/dart_dependency_injection) | 中文

- [开始使用](#开始使用)
- [ServiceCollection](#servicecollection)
  - [服务定义](#服务定义)
  - [添加服务](#添加服务)
    - [添加单例](#添加单例)
    - [添加范围单例](#添加范围单例)
    - [添加普通服务](#添加普通服务)
  - [生成ServiceProvider](#生成serviceprovider)
- [ServiceProvider](#serviceprovider)
  - [获取服务](#获取服务)
  - [服务初始化](#服务初始化)
  - [范围](#范围)
- [DependencyInjectionService](#dependencyinjectionservice)


## 开始使用

创建一个服务集合

```dart
var collection = ServiceCollection();
```

向服务集合添加服务：

```dart
// 添加一个普通服务
collection.add<TestService>((serviceProvider) => TestService());
// 添加一个单例服务
collection.addSingleton<TestSingletonService>((serviceProvider) => TestSingletonService());
// 添加一个范围单例服务
collection.addScopedSingleton<TestScopedSingletonService>((serviceProvider) => TestScopedSingletonService());
```

生成```ServiceProvider```：

```dart
var provider = collection.buildServiceProvider();
```

从```ServiceProvider```获取服务：

```dart
var testService = provider.get<TestService>();
```

## ServiceCollection

```ServiceCollection```表示一个服务集合，包含了全部的服务定义。

### 服务定义

服务定义包含以下几个属性

```dart
/// 是否单例
final bool isSingleton;

/// 是否范围单例
final bool isScopeSingleton;

/// 创建服务的方法
final T Function(ServiceProvider container) factory;
```

### 添加服务

```ServiceCollection```中添加服务的方法：

#### 添加单例

```dart
void addSingleton<T>(T Function(ServiceProvider serviceProvider) factory, {bool initializeWhenServiceProviderBuilt = false});
```

单例服务在当前范围以及服务全部的派生的服务范围中都仅有一个实例

#### 添加范围单例

```dart
void addScopedSingleton<T>(T Function(ServiceProvider serviceProvider) factory, {bool initializeWhenServiceProviderBuilt = false});
```

范围单例服务在不同得范围中获取到的服务是不同的实例，在相同的服务范围中获取的服务为同一个实例

#### 添加普通服务

```dart
void add<T>(T Function(ServiceProvider serviceProvider) factory, {bool initializeWhenServiceProviderBuilt = false})
```

普通服务每次获取均为不同实例

---

以上方法参数中的**initializeWhenServiceProviderBuilt**表示在生成```ServiceProvider```后是否立即初始化服务

### 生成ServiceProvider

生成一个顶级的```ServiceProvider```

```dart
ServiceProvider buildServiceProvider();
```

---

生成一个范围```ServiceProvider```

```dart
ServiceProvider buildScopeServiceProvider(ServiceProvider parent, {Object? scope});
```

**parent** 表示该范围```ServiceProvider```的父级

## ServiceProvider

```ServiceProvider```表示服务提供者，由```ServiceCollection```生成。

### 获取服务

```dart
/// 获取T类型的服务，服务未定义则抛出异常
T get<T extends Object>();
/// 尝试获取T类型的服务，服务未定义返回空
T? tryGet<T extends Object>();
/// 获取type类型的服务，服务未定义则抛出异常
dynamic getByType(Type type);
/// 尝试获取type类型的服务，服务未定义返回空
dynamic tryGetByType(Type type)
```

获取由```ServiceCollection```添加的服务，获取服务时**类型必须与添加服务的泛型类型一致**

### 服务初始化

如果获取服务时需要创建实例，那么创建实例后将会立即进行服务初始化。

如果注入的服务如果混入了```DependencyInjectionService```并且重写了```dependencyInjectionServiceInitialize```方法，那么将会在创建后立即执行该方法。

如果在添加服务时**initializeWhenServiceProviderBuilt**设置为true，那么将会在生成```ServiceProvider```后立即创建一次该服务，然后执行初始化。

编写初始化如下所示：

```dart
class TestService with DependencyInjectionService {
  @override
  FutureOr dependencyInjectionServiceInitialize(){
    print("run at service create");
  }
}
```

```dependencyInjectionServiceInitialize```方法可以异步，如果你使用了异步初始化，则以下两个方法可以等待异步初始化完成

```dart
/// 等待最近一个获取的服务初始化，必须在获取服务后立即等待
FutureOr waitLatestServiceInitialize();
/// 等待当前全部正在初始化的服务
FutureOr waitServicesInitialize();
```

### 范围

通过以下方法可以从当前```ServiceProvider```派生出一个范围，

```dart
ServiceProvider buildScope({void Function(ServiceCollection)? builder, Object? scope});
```

使用方式如下所示：

```dart
var testService = provider.get<TestService>();
var scopedServiceProvider = testService.buildScopeService(
    builder: (collection) {
        collection.add<TestService>((serviceProvider) => TestService());
    },
);
```

派生出来的范围将会继承自身的全部服务，并且可以通过```builder```在新的范围内添加额外的服务。使用新的范围获取服务时，如果是父级的单例服务那么将使用和父级相同的实例，如果是父级的范围单例服务，那么将在该范围内重新创建一个实例。

如果创建了一个范围，那么必须在不再使用它时执行它的```dispose```方法以便该范围内单例或者范围单例释放。

## DependencyInjectionService

```DependencyInjectionService```是一个mixin，通过依赖注入创建的服务如果混入了它，那么将获得一些魔法方法。

```dart
/// 获取服务
T getService<T extends Object>() => serviceProvider.get<T>();

/// 尝试获取服务，如果服务不存在返回null
T? tryGetService<T extends Object>() => serviceProvider.tryGet<T>();

/// 获取服务
dynamic getServiceByType(Type type) => serviceProvider.getByType(type);

/// 尝试获取服务，如果服务不存在返回null
dynamic tryGetServiceByType(Type type) => serviceProvider.tryGetByType(type);
```

和```ServiceProvider```一样，一套获取服务的方法。也就是说，你可以**在由依赖注入创建的服务中获取其他的依赖注入的服务**。

---

创建一个服务范围

```dart
ServiceProvider buildScopeService<T>({void Function(ServiceCollection)? builder, Object? scope});
```

和```ServiceProvider```一样，不过你无需担心创建的范围的```dispose```。因为它会在当前服务被dispose后执行。

---

等待服务初始化

```dart
FutureOr waitLatestServiceInitialize() => serviceProvider.waitLatestServiceInitialize();
FutureOr waitServicesInitialize() => serviceProvider.waitServicesInitialize();
```

和```ServiceProvider```一样，你可以在获取了某些异步服务后等待他们初始化完成。

---

这些方法都来自```ServiceProvider```，所以在使用它们时需要特别注意**当前服务所在的范围**。

1. 如果当前服务是单例服务，那么它所在的范围永远是定义它的那个范围。

1. 如果当前服务是普通服务或者范围单例服务，那么这个服务所在的范围是创建它的那个范围。
