import 'dart:convert';
import 'package:beacon_project/services/db_service.dart';
import 'package:beacon_project/models/device.dart';
import 'package:sqflite/sqflite.dart';

import 'payload_strategy.dart';
class HandshakePayloadStrategy implements PayloadStrategy {
  @override
  Future<void> handle(String endpointId, String message) async {
    // message format: "HANDSHAKE:{...json...}"
    final raw = message.substring("HANDSHAKE:".length);
    final data = json.decode(raw) as Map<String, dynamic>;
    final remoteUuid = data["uuid"] as String;
    final remoteName = (data["deviceName"] as String?) ?? "Unknown";

    final db = await DBService().database;

    // Look up existing row by endpointId
    final existing = await db.query(
      'devices',
      where: 'endpointId = ?',
      whereArgs: [endpointId],
    );

    if (existing.isNotEmpty) {
      // Build a new Device from the existing row, then override fields
      final current = Device.fromMap(existing.first);
      final updated = Device(
        uuid: remoteUuid,
        deviceName: remoteName,
        endpointId: current.endpointId,
        status: "Connected",
        lastSeen: DateTime.now(),
      );

      await db.update(
        'devices',
        updated.toMap(),
        where: 'endpointId = ?',
        whereArgs: [endpointId],
      );
    } else {
      // If not in DB yet, insert a new row directly
      final device = Device(
        uuid: remoteUuid,
        deviceName: remoteName,
        endpointId: endpointId,
        status: "Connected",
        lastSeen: DateTime.now(),
      );

      await db.insert(
        'devices',
        device.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }
}
