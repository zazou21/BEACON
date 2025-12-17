import 'package:mockito/annotations.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beacon_project/repositories/device_repository.dart';
import 'package:beacon_project/repositories/cluster_repository.dart';
import 'package:beacon_project/repositories/cluster_member_repository.dart';
import 'package:beacon_project/services/db_service.dart';
import 'package:beacon_project/services/nearby_connections/nearby_connections.dart';

@GenerateMocks([
  Nearby,
  SharedPreferences,
  DBService,
  NearbyConnectionsBase,
  NearbyConnectionsInitiator,
  NearbyConnectionsJoiner,
])
void main() {}
