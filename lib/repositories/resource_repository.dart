import '../models/resource.dart';
import '../models/device.dart';
import 'package:sqflite/sqlite_api.dart';
import '../services/db_service.dart';
import '../services/nearby_connections/nearby_connections.dart';


part 'db_resource_repository.dart';
part 'mock_resource_repository.dart';


/// Repository interface for Resource data operations
abstract class ResourceRepository {
  /// Fetch all resources from storage
  Future<List<Resource>> fetchResources();

  /// Fetch all connected devices in the cluster
  Future<List<Device>> fetchConnectedDevices();

  /// Insert a new resource into storage
  Future<void> insertResource(Resource resource);
}
