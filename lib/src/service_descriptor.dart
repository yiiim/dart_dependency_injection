part of './dart_dependency_injection.dart';

/// 服务描述
class ServiceDescriptor<T> {
  ServiceDescriptor(
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

  /// 传入的[descriptor]服务是否可以观察当前服务
  bool isObserver(ServiceDescriptor descriptor) {
    return descriptor is ServiceDescriptor<ServiceObserver<T>>;
  }

  /// 当前服务是否是[ServiceObserver]，并且是否可以观察[descriptor]服务
  // bool canObserver(ServiceDescriptor descriptor) {
  //   // return descriptor._observerDescriptorInstance is ServiceDescriptor<T>;
  // }

  // static ServiceObserver<T> _constServerObserverFactory<T>(ServiceProvider _) => throw "";
  // late final ServiceDescriptor<ServiceObserver> _observerDescriptorInstance = ServiceDescriptor<ServiceObserver<T>>(_constServerObserverFactory);
}
