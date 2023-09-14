import 'dart:async';

import 'package:dart_dependency_injection/dart_dependency_injection.dart';

class TestObserver extends ServiceObserver {
  @override
  void onServiceCreated(service) {
    print("CommonObserver: ${service.runtimeType} ${service.hashCode} created");
  }

  @override
  void onServiceDispose(service) {
    print("CommonObserver: ${service.runtimeType} ${service.hashCode} dispose");
  }

  @override
  void onServiceInitializeDone(service) {
    print("CommonObserver: ${service.runtimeType} ${service.hashCode} initialize done");
  }
}

class Test1Observer extends ServiceObserver<Test1Service> {
  @override
  void onServiceCreated(service) {
    print("Test1Observer: ${service.runtimeType} ${service.hashCode} created");
  }

  @override
  void onServiceDispose(service) {
    print("Test1Observer: ${service.runtimeType} ${service.hashCode} dispose");
  }

  @override
  void onServiceInitializeDone(service) {
    print("Test1Observer: ${service.runtimeType} ${service.hashCode} initialize done");
  }
}

class Test1Service with DependencyInjectionService {}

class TestService with DependencyInjectionService {
  late final Test1Service testService1;
  @override
  FutureOr dependencyInjectionServiceInitialize() {
    testService1 = getService<Test1Service>();
  }
}

void main() {
  var collection = ServiceCollection();
  collection.add<TestService>((serviceProvider) => TestService());
  collection.add<ServiceObserver>((serviceProvider) => TestObserver());
  collection.add<ServiceObserver<Test1Service>>((serviceProvider) => Test1Observer());
  var provider = collection.build();
  var scopedServiceProvider = provider.buildScoped(
    builder: (collection) {
      collection.addSingleton<Test1Service>((serviceProvider) => Test1Service());
    },
  );
  scopedServiceProvider.get<TestService>();
  scopedServiceProvider.dispose();
}
