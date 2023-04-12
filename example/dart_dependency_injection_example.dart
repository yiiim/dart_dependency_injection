import 'dart:async';

import 'package:dart_dependency_injection/dart_dependency_injection.dart';

class TestService with DependencyInjectionService {
  FutureOr Function(TestService service)? dependencyInjectionServiceInitializeFunction;
  @override
  FutureOr dependencyInjectionServiceInitialize() => dependencyInjectionServiceInitializeFunction?.call(this);
}

void main() {
  var collection = ServiceCollection();
  collection.add<TestService>((serviceProvider) => TestService());
  collection.addSingleton<TestService>((serviceProvider) => TestService());
  collection.addScopedSingleton<TestService>((serviceProvider) => TestService());
  var provider = collection.buildServiceProvider();
  var testService = provider.get<TestService>();
  var scopedServiceProvider = testService.buildScopedProvider(
    builder: (collection) {
      collection.add<TestService>((serviceProvider) => TestService());
    },
  );
  scopedServiceProvider.get<TestService>();
}
