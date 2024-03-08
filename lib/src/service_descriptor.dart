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

  /// configure service after creation
  final List<void Function(T service)> configurations = [];

  /// the service type
  Type get serviceType => T;

  /// can [descriptor] observe current service
  bool _isObserver(ServiceDescriptor descriptor) {
    bool result = descriptor._checkIsType(<ServiceObserver<T>>[]);
    return result;
  }

  bool _checkIsType(List typedList) {
    return typedList is List<T>;
  }

  /// call the service configuration
  void _callConfiguration(T service) {
    for (var element in configurations) {
      element.call(service);
    }
  }
}
