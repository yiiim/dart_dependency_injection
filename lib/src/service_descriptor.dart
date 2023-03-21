part of './dart_dependency_injection.dart';

/// 服务描述
class ServiceDescriptor<T> {
  const ServiceDescriptor(
    this.factory, {
    this.isSingleton = false,
    this.isScopeSingleton = false,
    this.createUseScope = false,
    this.useScopeBuilder,
  })  : assert(!(isSingleton && isScopeSingleton), "isSingleton and isScopeSingleton cannot both be true"),
        assert(!(isSingleton && createUseScope), "isSingleton and createUseScope cannot both be true");

  /// 是否单例
  final bool isSingleton;

  /// 是否范围单例
  final bool isScopeSingleton;

  /// 是否创建时创建一个范围
  final bool createUseScope;

  /// 当[createUseScope]为true时,创建范围时执行
  final void Function(ServiceCollection builder)? useScopeBuilder;

  /// 创建服务的方法
  final T Function(ServiceProvider container) factory;
}
