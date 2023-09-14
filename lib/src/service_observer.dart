part of './dart_dependency_injection.dart';

abstract class ServiceObserver<T extends Object> {
  void onServiceCreated(T service);
  void onServiceInitializeDone(T service);
  void onServiceDispose(T service);
}
