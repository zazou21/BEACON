abstract class PayloadStrategy {
  Future<void> handle(String endpointId, Map<String, dynamic> data);
}
