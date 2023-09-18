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

class Test2Service extends Test1Service {}

class TestService with DependencyInjectionService {
  late final Test1Service testService1;
  @override
  FutureOr dependencyInjectionServiceInitialize() {
    testService1 = getService<Test1Service>();
  }
}

class ValueClass {
  TClass? value = TClass();
}

class TClass {}

class A {
  A(this.finalizer);
  final Finalizer<A> finalizer;
  final ValueClass valueClass = ValueClass();
  late WeakReference<TClass> tc;

  void test(TClass t) {
    tc = WeakReference(TClass());
  }

  void test1() {
    print("test");
  }
}

void main() async {
  var tc = WeakReference(TClass());
  print(tc.target == null);
  Timer.periodic(
    Duration(seconds: 1),
    (timer) {
      print(tc.target == null);
    },
  );
  // Finalizer<A> f = Finalizer<A>((t) => t.test1());
  // A a = A(f);
  // ValueClass valueClass = ValueClass();

  // a.test(valueClass.value!);
  // print("${a.tc.target}");
  // Timer.periodic(
  //   Duration(seconds: 1),
  //   (timer) {
  //     if (timer.tick > 3) {
  //       valueClass.value = null;
  //     }
  //     print("${a.tc.target}${timer.tick}");
  //   },
  // );
  // var collection = ServiceCollection();
  // collection.add<TestService>((serviceProvider) => TestService());
  // collection.add<Test1Service>((serviceProvider) => Test1Service());
  // collection.add<Test2Service>((serviceProvider) => Test2Service());
  // collection.add<ServiceObserver>((serviceProvider) => TestObserver());
  // collection.add<Test1Observer>((serviceProvider) => Test1Observer());
  // var provider = collection.build();
  // provider.get<Test1Service>();
  // provider.get<Test2Service>();
  // provider.dispose();
}
