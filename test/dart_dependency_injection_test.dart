import 'dart:async';

import 'package:dart_dependency_injection/dart_dependency_injection.dart';
import 'package:test/test.dart';

class TestService with DependencyInjectionService {
  FutureOr Function(TestService service)? dependencyInjectionServiceInitializeFunction;
  @override
  FutureOr dependencyInjectionServiceInitialize() => dependencyInjectionServiceInitializeFunction?.call(this);
}

class TestServiceCopyType extends TestService {}

void main() {
  test(
    "test service",
    () {
      var collection = ServiceCollection();
      collection.add((serviceProvider) => TestService());
      var provider = collection.build();
      var scopedProvider1 = provider.buildScoped();
      var scopedProvider2 = provider.buildScoped();

      expect(provider.get<TestService>().hashCode != provider.get<TestService>().hashCode, isTrue);
      expect(scopedProvider1.get<TestService>().hashCode != scopedProvider1.get<TestService>().hashCode, isTrue);
      expect(scopedProvider2.get<TestService>().hashCode != scopedProvider2.get<TestService>().hashCode, isTrue);
      expect(provider.get<TestService>().hashCode != scopedProvider1.get<TestService>().hashCode, isTrue);
      expect(provider.get<TestService>().hashCode != scopedProvider2.get<TestService>().hashCode, isTrue);
      expect(scopedProvider1.get<TestService>().hashCode != scopedProvider2.get<TestService>().hashCode, isTrue);
    },
  );
  test(
    "test singleton service",
    () {
      var collection = ServiceCollection();
      collection.addScopedSingleton((serviceProvider) => TestService());
      var provider = collection.build();
      var scopedProvider1 = provider.buildScoped();
      var scopedProvider2 = provider.buildScoped();

      expect(provider.get<TestService>().hashCode == provider.get<TestService>().hashCode, isTrue);
      expect(scopedProvider1.get<TestService>().hashCode == scopedProvider1.get<TestService>().hashCode, isTrue);
      expect(scopedProvider2.get<TestService>().hashCode == scopedProvider2.get<TestService>().hashCode, isTrue);

      expect(provider.get<TestService>().hashCode != scopedProvider1.get<TestService>().hashCode, isTrue);
      expect(provider.get<TestService>().hashCode != scopedProvider2.get<TestService>().hashCode, isTrue);
      expect(scopedProvider1.get<TestService>().hashCode != scopedProvider2.get<TestService>().hashCode, isTrue);
    },
  );

  test(
    "test scoped singleton service",
    () {
      var collection = ServiceCollection();
      collection.addSingleton((serviceProvider) => TestService());
      var provider = collection.build();
      var scopedProvider1 = provider.buildScoped();
      var scopedProvider2 = provider.buildScoped();

      expect(provider.get<TestService>().hashCode == provider.get<TestService>().hashCode, isTrue);
      expect(provider.get<TestService>().hashCode == scopedProvider1.get<TestService>().hashCode, isTrue);
      expect(scopedProvider1.get<TestService>().hashCode == scopedProvider2.get<TestService>().hashCode, isTrue);
    },
  );

  test(
    "test service initialize",
    () {
      bool isInit = false;
      var collection = ServiceCollection();
      collection.add(
        (serviceProvider) => TestService()
          ..dependencyInjectionServiceInitializeFunction = (service) {
            isInit = true;
          },
      );
      var provider = collection.build();
      provider.get<TestService>();
      expect(isInit, isTrue);
    },
  );

  test(
    "test service async initialize",
    () async {
      bool isInit = false;
      var collection = ServiceCollection();
      collection.add(
        (serviceProvider) => TestService()
          ..dependencyInjectionServiceInitializeFunction = (service) async {
            await Future.delayed(Duration(seconds: 3));
            isInit = true;
          },
      );
      var provider = collection.build();
      provider.get<TestService>();
      expect(isInit, isFalse);
      await provider.waitLatestServiceInitialize();
      expect(isInit, isTrue);
    },
  );
  test(
    "test service deep async initialize",
    () async {
      bool isInit = false;
      bool isCopyInit = false;
      var collection = ServiceCollection();
      collection.add<TestService>(
        (serviceProvider) => TestService()
          ..dependencyInjectionServiceInitializeFunction = (service) async {
            await Future.delayed(Duration(seconds: 3));
            service.getService<TestServiceCopyType>();
            isInit = true;
          },
      );
      collection.addScopedSingleton<TestServiceCopyType>(
        (serviceProvider) => TestServiceCopyType()
          ..dependencyInjectionServiceInitializeFunction = (service) async {
            await Future.delayed(Duration(seconds: 3));
            isCopyInit = true;
          },
      );
      var provider = collection.build();
      var scopedProvider = provider.buildScoped();
      scopedProvider.get<TestService>();
      expect(isInit, isFalse);
      expect(isCopyInit, isFalse);
      await scopedProvider.waitServicesInitialize();
      expect(isInit, isTrue);
      expect(isCopyInit, isTrue);
    },
  );
}
