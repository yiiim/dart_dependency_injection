part of './dart_dependency_injection.dart';

/// The service observer
///
/// add this interface to [ServiceCollection], you can observe service's lifecycle
abstract class ServiceObserver<T> {
  void onServiceCreated(T? service);
  void onServiceInitializeDone(T? service);
  void onServiceDispose(T? service);
}
