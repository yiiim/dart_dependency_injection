import 'package:dart_dependency_injection/dart_dependency_injection.dart';

class TestService2 {}

class TestService3 {}

class TestService with DependencyInjectionService {
  void log(String text) {
    getService<TestService2>();
    print(text);
  }
}

class TestObserver extends ServiceObserver with DependencyInjectionService {
  @override
  void onServiceCreated(service) {
    getService<TestService>().log("${service.runtimeType} created");
  }

  @override
  void onServiceDispose(service) {}

  @override
  void onServiceInitializeDone(service) {}
}

void main() async {
  var serviceCollection = ServiceCollection();
  serviceCollection.addSingleton<TestService>((serviceProvider) => TestService());
  serviceCollection.addSingleton<TestService2>((serviceProvider) => TestService2());
  serviceCollection.addSingleton<TestService3>((serviceProvider) => TestService3(), initializeWhenServiceProviderBuilt: true);
  serviceCollection.add<ServiceObserver>((serviceProvider) => TestObserver());
  serviceCollection.build();
}
