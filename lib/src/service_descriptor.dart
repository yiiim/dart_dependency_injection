part of './dart_dependency_injection.dart';

/// 服务描述
class ServiceDescriptor<T> {
  const ServiceDescriptor(
    this.factory, {
    this.isSingleton = false,
    this.isScopeSingleton = false,
  }) : assert(!(isSingleton && isScopeSingleton), "isSingleton and isScopeSingleton cannot both be true");

  /// 是否单例
  final bool isSingleton;

  /// 是否范围单例
  final bool isScopeSingleton;

  /// 创建服务的方法
  final T Function(ServiceProvider container) factory;

  /// 服务类型
  Type get serviceType => T;

  /// [descriptor]是否是当前服务的观察者
  bool isObserver(ServiceDescriptor descriptor) {
    var instance = descriptor.createTempObserverInstance();
    var result = instance is ServiceDescriptor<T>;
    return result;
  }

  ServiceDescriptor<ServiceObserver> createTempObserverInstance() {
    return ServiceDescriptor<ServiceObserver<T>>((_) => ServiceObserver<T>());
  }
}
