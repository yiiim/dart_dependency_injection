part of './dart_dependency_injection.dart';

/// The service descriptor
class ServiceDescriptor<T> {
  ServiceDescriptor(
    this.factory, {
    this.isSingleton = false,
    this.isScopeSingleton = false,
  }) : assert(!(isSingleton && isScopeSingleton), "isSingleton and isScopeSingleton cannot both be true");

  /// is singleton
  final bool isSingleton;

  /// is scope singleton
  final bool isScopeSingleton;

  /// the service factory
  final T Function(ServiceProvider container) factory;

  /// the service type
  Type get serviceType => T;

  /// can [descriptor] observe current service
  bool _isObserver(ServiceDescriptor descriptor) {
    var result = descriptor.serviceType == ServiceObserver<T>;
    return result;
  }
}
