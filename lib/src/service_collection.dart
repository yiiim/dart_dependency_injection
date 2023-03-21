part of './dart_dependency_injection.dart';

/// 服务集合
class ServiceCollection {
  ServiceCollection({this.allowOverrides = false});
  final Map<Type, ServiceDescriptor> _serviceDescriptor = {};
  final Map<Type, ServiceDescriptor> _initializeWhenProviderBuilt = {};

  /// 是否运行覆盖
  final bool allowOverrides;

  /// 添加一个服务
  ///
  /// [serviceDescriptor] 服务描述
  /// [initializeWhenServiceProviderBuilt] 是否在build之后立即初始化
  void addServiceDescriptor<T>(ServiceDescriptor<T> serviceDescriptor, {bool initializeWhenServiceProviderBuilt = false}) {
    if (_serviceDescriptor.containsKey(T)) {
      if (allowOverrides) {
        _serviceDescriptor.remove(T);
      } else {
        throw Exception('Service already exists');
      }
    }

    _serviceDescriptor.putIfAbsent(T, () => serviceDescriptor);
    if (initializeWhenServiceProviderBuilt) {
      _initializeWhenProviderBuilt.putIfAbsent(T, () => serviceDescriptor);
    }
  }

  /// 添加一个单例服务，该服务在[ServiceProvider]只存在一个实例
  ///
  /// [factory] 服务创建方法
  /// [initializeWhenServiceProviderBuilt] 是否在build[ServiceProvider]之后立即初始化
  void addSingleton<T>(T Function(ServiceProvider serviceProvider) factory, {bool initializeWhenServiceProviderBuilt = false}) {
    addServiceDescriptor<T>(ServiceDescriptor<T>((serviceProvider) => factory(serviceProvider), isSingleton: true), initializeWhenServiceProviderBuilt: initializeWhenServiceProviderBuilt);
  }

  /// 添加一个范围单例服务, 该服务在每个范围内存在一个实例
  ///
  /// [factory] 服务创建方法
  /// [createUseScope] 是否在创建这个范围单例时创建一个范围，每次获取该服务都将将重新创建，并且创建一个范围，否则，在每个范围内该服务保持单例
  /// [useScopeBuilder] 当[createUseScope]是true的时候, 创建范围[ServiceProvider]的[ServiceCollection]
  /// [initializeWhenServiceProviderBuilt] 是否在build[ServiceProvider]之后立即初始化
  void addScopedSingleton<T>(T Function(ServiceProvider serviceProvider) factory, {bool createUseScope = false, void Function(ServiceCollection builder)? useScopeBuilder, bool initializeWhenServiceProviderBuilt = false}) => addServiceDescriptor<T>(
        ServiceDescriptor<T>(
          (serviceProvider) => factory(serviceProvider),
          isScopeSingleton: true,
          createUseScope: createUseScope,
          useScopeBuilder: useScopeBuilder,
        ),
        initializeWhenServiceProviderBuilt: initializeWhenServiceProviderBuilt,
      );

  /// 添加一个服务，每次获取服务都是不同实例
  ///
  /// [factory] 服务创建方法
  /// [createUseScope] 是否在创建这个范围单例时创建一个范围，这样每次获取该服务都将将重新创建，并且创建一个范围，否则，在每个范围内该服务保持单例
  /// [useScopeBuilder] 当[createUseScope]是true的时候, 创建范围[ServiceProvider]的[ServiceCollection]
  /// [initializeWhenServiceProviderBuilt] 是否在build[ServiceProvider]之后立即初始化
  void add<T>(T Function(ServiceProvider serviceProvider) factory, {bool createUseScope = false, void Function(ServiceCollection builder)? useScopeBuilder, bool initializeWhenServiceProviderBuilt = false}) => addServiceDescriptor<T>(
        ServiceDescriptor<T>(
          (serviceProvider) => factory(serviceProvider),
          createUseScope: createUseScope,
          useScopeBuilder: useScopeBuilder,
        ),
        initializeWhenServiceProviderBuilt: initializeWhenServiceProviderBuilt,
      );

  /// 创建一个[ServiceProvider]，包含[parent]和当前[ServiceCollection]中的服务
  ///
  /// [scope]范围标识
  ServiceProvider buildScopeServiceProvider(ServiceProvider parent, {Object? scope}) {
    var provider = ServiceProvider(
      Map<Type, ServiceDescriptor<dynamic>>.unmodifiable(
        _serviceDescriptor,
      ),
      parent: parent,
      scope: scope,
    );
    for (var element in _initializeWhenProviderBuilt.keys) {
      provider.__get(_initializeWhenProviderBuilt[element]!, element);
    }
    return provider;
  }

  /// 创建一个[ServiceProvider],包含当前[ServiceCollection]中的服务
  ServiceProvider buildServiceProvider() {
    var provider = ServiceProvider(
      Map<Type, ServiceDescriptor<dynamic>>.unmodifiable(
        _serviceDescriptor,
      ),
    );
    for (var element in _initializeWhenProviderBuilt.keys) {
      provider.__get(_initializeWhenProviderBuilt[element]!, element);
    }
    return provider;
  }
}
