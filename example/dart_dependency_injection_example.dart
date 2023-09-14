import 'dart:async';

import 'package:dart_dependency_injection/dart_dependency_injection.dart';

class TestObserver extends ServiceObserver {
  @override
  void onServiceCreated(service) {
    print("$service created");
  }

  @override
  void onServiceDispose(service) {
    print("$service dispose");
  }

  @override
  void onServiceInitializeDone(service) {
    print("$service initialize done");
  }
}

class Test1Service {}

class TestService with DependencyInjectionService {
  late final Test1Service testService1;
  @override
  FutureOr dependencyInjectionServiceInitialize() {
    testService1 = getService<Test1Service>();
    print("TestService Init");
  }
}

void main() {
  var collection = ServiceCollection();
  collection.add<TestService>((serviceProvider) => TestService());
  collection.add<ServiceObserver>((serviceProvider) => TestObserver());
  collection.addSingleton<Test1Service>((serviceProvider) => Test1Service());
  var provider = collection.build();
  var testService = provider.get<TestService>();
  var scopedServiceProvider = testService.buildScopedServiceProvider(
    builder: (collection) {
      collection.add<TestService>((serviceProvider) => TestService());
    },
  );
  scopedServiceProvider.get<TestService>();
}
