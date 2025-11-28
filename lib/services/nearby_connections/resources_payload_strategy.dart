import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import 'package:beacon_project/services/db_service.dart';
import 'package:beacon_project/models/resource.dart';
import 'payload_strategy.dart';


class ResourcesPayloadStrategy implements PayloadStrategy{
  @override
  Future<void> handle(String endpointId, Map<String, dynamic> data) async {
    final resources = data['resources'] as List<dynamic>?;

    if (resources == null) return;

    final db = await DBService().database;

    // Save resources
    for (final r in resources) {
      final resourceMap = Map<String, dynamic>.from(r);

      final existing = await db.query(
        'resources',
        where: 'resourceId = ?',
        whereArgs: [resourceMap['resourceId']],
      );

      final resource=Resource.fromMap(resourceMap);

      debugPrint('Received resource: ${resource.resourceName}');
      
      if (existing.isNotEmpty) {
        await db.update(
          'resources',
          resource.toMap(),
          where: 'resourceId = ?',
          whereArgs: [resource.resourceId],
        );
      } else {
        await db.insert(
          'resources',
          resource.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }

    














}


