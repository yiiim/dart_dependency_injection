import 'package:dart_dependency_injection/dart_dependency_injection.dart';

class TestService with DependencyInjectionService {}

void main() async {
  var serviceCollection = ServiceCollection();
  serviceCollection.addSingleton((serviceProvider) => TestService());
  var serviceProvider = serviceCollection.build();
  var testService = serviceProvider.get<TestService>();
  print(testService);
}
