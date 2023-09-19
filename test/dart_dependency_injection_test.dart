import 'dart:async';

import 'package:dart_dependency_injection/dart_dependency_injection.dart';
import 'package:test/test.dart';

class TestObserver extends ServiceObserver {
  TestObserver({
    this.onServiceCreatedFunc,
    this.onServiceDisposeFunc,
    this.onServiceInitializeDoneFunc,
  });
  final void Function(dynamic service)? onServiceCreatedFunc;
  final void Function(dynamic service)? onServiceDisposeFunc;
  final void Function(dynamic service)? onServiceInitializeDoneFunc;

  @override
  void onServiceCreated(service) {
    onServiceCreatedFunc?.call(service);
  }

  @override
  void onServiceDispose(service) {
    onServiceDisposeFunc?.call(service);
  }

  @override
  void onServiceInitializeDone(service) {
    onServiceInitializeDoneFunc?.call(service);
  }
}

class TestTypedObserver<T> extends ServiceObserver<T> {
  TestTypedObserver({
    this.onServiceCreatedFunc,
    this.onServiceDisposeFunc,
    this.onServiceInitializeDoneFunc,
  });
  final void Function(dynamic service)? onServiceCreatedFunc;
  final void Function(dynamic service)? onServiceDisposeFunc;
  final void Function(dynamic service)? onServiceInitializeDoneFunc;

  @override
  void onServiceCreated(service) {
    onServiceCreatedFunc?.call(service);
  }

  @override
  void onServiceDispose(service) {
    onServiceDisposeFunc?.call(service);
  }

  @override
  void onServiceInitializeDone(service) {
    onServiceInitializeDoneFunc?.call(service);
  }
}

class TestOtherObserverService with DependencyInjectionService {
  FutureOr Function(TestOtherObserverService service)? dependencyInjectionServiceInitializeFunction;
  FutureOr Function(TestOtherObserverService service)? dependencyInjectionServiceDisposeFunction;
  @override
  FutureOr dependencyInjectionServiceInitialize() => dependencyInjectionServiceInitializeFunction?.call(this);

  @override
  void dispose() {
    super.dispose();
    dependencyInjectionServiceDisposeFunction?.call(this);
  }
}

class TestService with DependencyInjectionService {
  FutureOr Function(TestService service)? dependencyInjectionServiceInitializeFunction;
  FutureOr Function(TestService service)? dependencyInjectionServiceDisposeFunction;
  @override
  FutureOr dependencyInjectionServiceInitialize() => dependencyInjectionServiceInitializeFunction?.call(this);

  @override
  void dispose() {
    super.dispose();
    dependencyInjectionServiceDisposeFunction?.call(this);
  }
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
            await Future.delayed(Duration(seconds: 1));
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
            await Future.delayed(Duration(seconds: 1));
            service.getService<TestServiceCopyType>();
            isInit = true;
          },
      );
      collection.addScopedSingleton<TestServiceCopyType>(
        (serviceProvider) => TestServiceCopyType()
          ..dependencyInjectionServiceInitializeFunction = (service) async {
            await Future.delayed(Duration(seconds: 1));
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

  test(
    "test singleton dispose",
    () async {
      bool isDispose = false;
      var collection = ServiceCollection();
      collection.addSingleton<TestService>(
        (serviceProvider) => TestService()
          ..dependencyInjectionServiceDisposeFunction = (service) {
            isDispose = true;
          },
      );
      var provider = collection.build();
      var scopedProvider = provider.buildScoped();
      provider.get<TestService>();
      expect(scopedProvider.getExistSingleton(TestService), isNotNull);
      expect(provider.getExistSingleton(TestService), isNotNull);
      expect(isDispose, isFalse);
      provider.dispose();
      expect(isDispose, isTrue);
      expect(scopedProvider.getExistSingleton(TestService), isNull);
      expect(provider.getExistSingleton(TestService), isNull);
    },
  );

  test(
    "test scope singleton dispose",
    () async {
      bool isDispose = false;
      var collection = ServiceCollection();
      collection.addScopedSingleton<TestService>(
        (serviceProvider) => TestService()
          ..dependencyInjectionServiceDisposeFunction = (service) {
            isDispose = true;
          },
      );
      var provider = collection.build();
      var scopedProvider = provider.buildScoped();
      scopedProvider.get<TestService>();
      expect(scopedProvider.getExistScopedSingleton(TestService), isNotNull);
      expect(provider.getExistScopedSingleton(TestService), isNull);
      expect(isDispose, isFalse);
      scopedProvider.dispose();
      expect(isDispose, isTrue);
      expect(scopedProvider.getExistScopedSingleton(TestService), isNull);
      expect(provider.getExistScopedSingleton(TestService), isNull);

      isDispose = false;
      provider.get<TestService>();
      expect(scopedProvider.getExistScopedSingleton(TestService), isNull);
      expect(provider.getExistScopedSingleton(TestService), isNotNull);
      expect(isDispose, isFalse);
      provider.dispose();
      expect(isDispose, isTrue);
      expect(scopedProvider.getExistScopedSingleton(TestService), isNull);
      expect(provider.getExistScopedSingleton(TestService), isNull);
    },
  );

  test(
    "test transient service dispose",
    () async {
      var collection = ServiceCollection();
      collection.add<TestService>((serviceProvider) => TestService());
      var provider = collection.build();
      var scopedProvider = provider.buildScoped();
      scopedProvider.get<TestService>();
      expect(scopedProvider.getExistTransient(TestService)?.isNotEmpty, isTrue);
      Future<bool> checkDispose() async {
        // 这是为了测试普通服务被dart回收
        for (var i = 0; i < 1000; i++) {
          await Future.delayed(Duration(milliseconds: 10));
          TestService();
          if (scopedProvider.getExistTransient(TestService)?.isEmpty ?? true) {
            return true;
          }
        }
        return false;
      }

      expect(await checkDispose(), isTrue, reason: "debug mode may be failed");
    },
  );

  test(
    "test singleton self dispose",
    () async {
      bool isDispose = false;
      var collection = ServiceCollection();
      collection.addSingleton<TestService>(
        (serviceProvider) => TestService()..dependencyInjectionServiceDisposeFunction = (service) => isDispose = true,
      );
      var provider = collection.build();
      var singleton = provider.get<TestService>();
      expect(provider.getExistSingleton(TestService), isNotNull);
      expect(isDispose, isFalse);
      singleton.dispose();
      expect(isDispose, isTrue);
      expect(provider.getExistSingleton(TestService), isNull);
    },
  );

  test(
    "test scope singleton self dispose",
    () async {
      bool isDispose = false;
      var collection = ServiceCollection();
      collection.addScopedSingleton<TestService>(
        (serviceProvider) => TestService()..dependencyInjectionServiceDisposeFunction = (service) => isDispose = true,
      );
      var provider = collection.build();

      var scopeSingleton = provider.get<TestService>();
      expect(provider.getExistScopedSingleton(TestService), isNotNull);
      expect(isDispose, isFalse);
      scopeSingleton.dispose();
      expect(isDispose, isTrue);
      expect(provider.getExistScopedSingleton(TestService), isNull);

      isDispose = false;
      var scopedProvider = provider.buildScoped();
      var scopedProviderScopeSingleton = scopedProvider.get<TestService>();
      expect(scopedProvider.getExistScopedSingleton(TestService), isNotNull);
      expect(isDispose, isFalse);
      scopedProviderScopeSingleton.dispose();
      expect(isDispose, isTrue);
      expect(scopedProvider.getExistScopedSingleton(TestService), isNull);
    },
  );

  test(
    "test transient service self dispose",
    () {
      bool isDispose = false;
      var collection = ServiceCollection();
      collection.add<TestService>(
        (serviceProvider) => TestService()..dependencyInjectionServiceDisposeFunction = (service) => isDispose = true,
      );
      var provider = collection.build();

      var scopedProvider = provider.buildScoped();
      var transientService = scopedProvider.get<TestService>();
      expect(scopedProvider.getExistTransient(TestService)?.isNotEmpty, isTrue);
      transientService.dispose();
      expect(isDispose, isTrue);
      expect((scopedProvider.getExistTransient(TestService)?.isEmpty ?? true), isTrue);
    },
  );

  test(
    "test observer",
    () async {
      bool isDispose = false;
      bool isCreated = false;
      bool isInitDone = false;
      bool isOtherDispose = false;
      bool isOtherCreated = false;
      bool isOtherInitDone = false;
      var collection = ServiceCollection();
      collection.add<TestService>(
        (serviceProvider) {
          var service = TestService();
          service.dependencyInjectionServiceInitializeFunction = (service) async {
            await Future.delayed(Duration(seconds: 1));
          };
          return service;
        },
      );
      collection.add<TestOtherObserverService>(
        (serviceProvider) {
          var service = TestOtherObserverService();
          service.dependencyInjectionServiceInitializeFunction = (service) async {
            await Future.delayed(Duration(seconds: 1));
          };
          return service;
        },
      );
      collection.add<ServiceObserver>(
        (serviceProvider) => TestObserver(
          onServiceCreatedFunc: (service) {
            expect(service, isNotNull);
            if (service is TestService) isCreated = true;
            if (service is TestOtherObserverService) isOtherCreated = true;
          },
          onServiceDisposeFunc: (service) {
            expect(service, isNotNull);
            if (service is TestService) isDispose = true;
            if (service is TestOtherObserverService) isOtherDispose = true;
          },
          onServiceInitializeDoneFunc: (service) {
            expect(service, isNotNull);
            if (service is TestService) isInitDone = true;
            if (service is TestOtherObserverService) isOtherInitDone = true;
          },
        ),
      );

      var provider = collection.build();
      provider.get<TestService>();
      provider.get<TestOtherObserverService>();
      expect(isCreated, isTrue);
      expect(isInitDone, isFalse);
      expect(isDispose, isFalse);

      expect(isOtherCreated, isTrue);
      expect(isOtherInitDone, isFalse);
      expect(isOtherDispose, isFalse);
      await provider.waitServicesInitialize();
      await Future(() {});
      expect(isInitDone, isTrue);
      expect(isDispose, isFalse);
      expect(isOtherInitDone, isTrue);
      expect(isOtherDispose, isFalse);
      provider.dispose();
      expect(isDispose, isTrue);
      expect(isOtherDispose, isTrue);
    },
  );

  test(
    "test typed observer1",
    () async {
      bool isDispose = false;
      bool isCreated = false;
      bool isInitDone = false;
      bool isOtherDispose = false;
      bool isOtherCreated = false;
      bool isOtherInitDone = false;
      var collection = ServiceCollection();
      collection.add<TestService>(
        (serviceProvider) {
          var service = TestService();
          service.dependencyInjectionServiceInitializeFunction = (service) async {
            await Future.delayed(Duration(seconds: 1));
          };
          return service;
        },
      );
      collection.add<TestOtherObserverService>(
        (serviceProvider) {
          var service = TestOtherObserverService();
          service.dependencyInjectionServiceInitializeFunction = (service) async {
            await Future.delayed(Duration(seconds: 1));
          };
          return service;
        },
      );
      collection.add<ServiceObserver<TestService>>(
        (serviceProvider) => TestTypedObserver<TestService>(
          onServiceCreatedFunc: (service) {
            expect(service, isNotNull);
            if (service is TestService) isCreated = true;
            if (service is TestOtherObserverService) isOtherCreated = true;
          },
          onServiceDisposeFunc: (service) {
            expect(service, isNotNull);
            if (service is TestService) isDispose = true;
            if (service is TestOtherObserverService) isOtherDispose = true;
          },
          onServiceInitializeDoneFunc: (service) {
            expect(service, isNotNull);
            if (service is TestService) isInitDone = true;
            if (service is TestOtherObserverService) isOtherInitDone = true;
          },
        ),
      );
      var provider = collection.build();
      provider.get<TestService>();
      provider.get<TestOtherObserverService>();

      expect(isCreated, isTrue);
      expect(isInitDone, isFalse);
      expect(isDispose, isFalse);

      expect(isOtherCreated, isFalse);
      expect(isOtherInitDone, isFalse);
      expect(isOtherDispose, isFalse);
      await provider.waitServicesInitialize();
      await Future(() {});
      expect(isInitDone, isTrue);
      expect(isDispose, isFalse);
      expect(isOtherInitDone, isFalse);
      expect(isOtherDispose, isFalse);
      provider.dispose();
      expect(isDispose, isTrue);
      expect(isOtherDispose, isFalse);
    },
  );

  test(
    "test typed observer2",
    () async {
      bool isDispose = false;
      bool isCreated = false;
      bool isInitDone = false;
      bool isOtherDispose = false;
      bool isOtherCreated = false;
      bool isOtherInitDone = false;
      var collection = ServiceCollection();
      collection.add<TestService>(
        (serviceProvider) {
          var service = TestService();
          service.dependencyInjectionServiceInitializeFunction = (service) async {
            await Future.delayed(Duration(seconds: 1));
          };
          return service;
        },
      );
      collection.add<TestOtherObserverService>(
        (serviceProvider) {
          var service = TestOtherObserverService();
          service.dependencyInjectionServiceInitializeFunction = (service) async {
            await Future.delayed(Duration(seconds: 1));
          };
          return service;
        },
      );
      collection.add<ServiceObserver<TestOtherObserverService>>(
        (serviceProvider) => TestTypedObserver<TestOtherObserverService>(
          onServiceCreatedFunc: (service) {
            expect(service, isNotNull);
            if (service is TestService) isCreated = true;
            if (service is TestOtherObserverService) isOtherCreated = true;
          },
          onServiceDisposeFunc: (service) {
            expect(service, isNotNull);
            if (service is TestService) isDispose = true;
            if (service is TestOtherObserverService) isOtherDispose = true;
          },
          onServiceInitializeDoneFunc: (service) {
            expect(service, isNotNull);
            if (service is TestService) isInitDone = true;
            if (service is TestOtherObserverService) isOtherInitDone = true;
          },
        ),
      );
      var provider = collection.build();
      provider.get<TestService>();
      provider.get<TestOtherObserverService>();

      expect(isCreated, isFalse);
      expect(isInitDone, isFalse);
      expect(isDispose, isFalse);

      expect(isOtherCreated, isTrue);
      expect(isOtherInitDone, isFalse);
      expect(isOtherDispose, isFalse);
      await provider.waitServicesInitialize();
      await Future(() {});
      expect(isInitDone, isFalse);
      expect(isDispose, isFalse);

      expect(isOtherInitDone, isTrue);
      expect(isOtherDispose, isFalse);
      provider.dispose();
      expect(isDispose, isFalse);

      expect(isOtherDispose, isTrue);
    },
  );
}
