part of './dart_dependency_injection.dart';

class ServiceObserver<T> {
  void onServiceCreated(T service) {}
  void onServiceInitializeDone(T service) {}
  void onServiceDispose(T service) {}
}
