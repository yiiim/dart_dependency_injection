part of './dart_dependency_injection.dart';

abstract class ServiceObserver<T> {
  void onServiceCreated(service);
  void onServiceInitializeDone(service);
  void onServiceDispose(service);
}

abstract class ServiceDebugger {
  void addServiceObserver<T extends Object>(ServiceObserver<T> Function() observerFactory) {}
}
