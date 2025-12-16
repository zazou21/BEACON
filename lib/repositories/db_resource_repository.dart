part of 'resource_repository.dart';
/// Database implementation of ResourceRepository
class DbResourceRepository implements ResourceRepository {
  final DBService dbService;
  final NearbyConnectionsBase beacon;

  DbResourceRepository({
    required this.dbService,
    required this.beacon,
  });

  @override
  Future<List<Resource>> fetchResources() async {
    final database = await dbService.database;
    final List<Map<String, dynamic>> maps = await database.query('resources');
    return List.generate(maps.length, (i) => Resource.fromMap(maps[i]));
  }

  @override
  Future<List<Device>> fetchConnectedDevices() async {
    final database = await dbService.database;
    final String? deviceUuid = beacon.uuid;

    final joined = await database.query(
      'cluster_members',
      columns: ['clusterId'],
      where: 'deviceUuid = ?',
      whereArgs: [deviceUuid],
    );

    if (joined.isEmpty) return [];

    final clusterId = joined.first['clusterId'] as String;

    final List<Map<String, dynamic>> maps = await database.query(
      'devices',
      where:
          'uuid IN (SELECT deviceUuid FROM cluster_members WHERE clusterId = ?)',
      whereArgs: [clusterId],
    );

    return List.generate(maps.length, (i) => Device.fromMap(maps[i]));
  }

  @override
  Future<void> insertResource(Resource resource) async {
    final database = await dbService.database;
    await database.insert(
      'resources',
      resource.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
