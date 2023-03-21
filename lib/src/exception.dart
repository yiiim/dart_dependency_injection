part of './dart_dependency_injection.dart';

class ServiceNotFoundException implements Exception {
  const ServiceNotFoundException(this.message);

  final String message;
  @override
  String toString() => 'ServiceNotFoundException: $message';
}
