import 'dart:async';

import 'package:dart_dependency_injection/dart_dependency_injection.dart';

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
  collection.addSingleton<TestService>((serviceProvider) => TestService());
  collection.addScopedSingleton<TestService>((serviceProvider) => TestService());
  var provider = collection.build();
  var testService = provider.get<TestService>();
  var scopedServiceProvider = testService.buildScopedServiceProvider(
    builder: (collection) {
      collection.add<TestService>((serviceProvider) => TestService());
    },
  );
  scopedServiceProvider.get<TestService>();
}
