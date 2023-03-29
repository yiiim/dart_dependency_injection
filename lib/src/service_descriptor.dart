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
}
