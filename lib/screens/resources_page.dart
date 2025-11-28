import 'package:beacon_project/services/nearby_connections/nearby_connections.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sql.dart';
import '../models/resource.dart';
import '../services/db_service.dart';
import 'package:uuid/uuid.dart';
import 'package:beacon_project/models/device.dart';

// Optional: control tab order explicitly
const List<ResourceType> resourceTabOrder = [
  ResourceType.medical,
  ResourceType.foodWater,
  ResourceType.shelter,
];

extension ResourceTypeUi on ResourceType {
  String get label => switch (this) {
        ResourceType.medical => 'Medical',
        ResourceType.foodWater => 'Food & Water',
        ResourceType.shelter => 'Shelter',
      };

  String get subtitle => switch (this) {
        ResourceType.medical => 'Medicine, first aid, transport',
        ResourceType.foodWater => 'Food supplies, clean water, nutrition',
        ResourceType.shelter => 'Temporary housing, blankets, tents',
      };

  IconData get icon => switch (this) {
        ResourceType.medical => Icons.medical_services_outlined,
        ResourceType.foodWater => Icons.restaurant_menu,
        ResourceType.shelter => Icons.home_outlined,
      };
}



  String _timeAgo(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);

  if (diff.inSeconds < 60) return "Just now";
  if (diff.inMinutes < 60) return "${diff.inMinutes} min ago";
  if (diff.inHours < 24) return "${diff.inHours} hours ago";
  if (diff.inDays < 7) return "${diff.inDays} days ago";

  return "${dt.day}/${dt.month}/${dt.year}";
}
class ResourcePage extends StatefulWidget {
  const ResourcePage({super.key});
  @override
  State<ResourcePage> createState() => _ResourcePageState();
}

class _ResourcePageState extends State<ResourcePage> {
  ResourceType _selected = ResourceType.foodWater;
  List<Resource>? resources;
  late List<Device> connectedDevices;
  String clusterId = '';

  final db = DBService().database;
  final beacon = NearbyConnections();

  void _changeTab(ResourceType type) {
    setState(() => _selected = type);
  }

  Future<String> getClusterId() async {
    final database = await db;
    final String deviceUuid = await beacon.uuid;

    final result = await database.query(
      'cluster_members',
      columns: ['clusterId'],
      where: 'deviceUuid = ?',       
      whereArgs: [deviceUuid],
    );

    if (result.isNotEmpty) {
      return result.first['clusterId'] as String;
    }

    return '';
  }

  Future<List<Resource>> fetchResources() async {
    final database = await db;
    final List<Map<String, dynamic>> maps =
        await database.query('resources');

    debugPrint('Fetched ${maps.length} resources from database');

    if (maps.isEmpty){
      debugPrint('No resources found in database');
      return [];
    }


    return List.generate(maps.length, (i) {
      return Resource.fromMap(maps[i]);
    });
  }

 
  Future<List<Device>> fetchConnectedDevices() async {
    final database = await db;
    final String deviceUuid = await beacon.uuid;

  
    final joined = await database.query(
      'cluster_members',
      columns: ['clusterId'],
      where: 'deviceUuid = ?',     
      whereArgs: [deviceUuid],
    );

    if (joined.isEmpty) {
      return [];
    }

    clusterId = joined.first['clusterId'] as String;

    final List<Map<String, dynamic>> maps = await database.query(
      'devices',
      where:
          'uuid IN (SELECT deviceUuid FROM cluster_members WHERE clusterId = ?)',
      whereArgs: [clusterId],
    );

    debugPrint(
        'Fetched ${maps.length} connected devices for cluster $clusterId');

    return List.generate(maps.length, (i) {
      return Device.fromMap(maps[i]);
    });
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await beacon.init();

    final res = await fetchResources();
    final devices = await fetchConnectedDevices();

    if (!mounted) return;
    setState(() {
      resources = res;
      connectedDevices = devices;
    });
  }

  

  void _showResourceDetails(BuildContext context, Resource resource) {
  final Device? owner = connectedDevices.firstWhere(
    (d) => d.uuid == resource.userUuid,
    orElse: () => Device(
      uuid: resource.userUuid,
      deviceName: "Unknown device",
      endpointId: "",
      status: "Unknown",
      lastSeen: DateTime.now(),
    ),
  );

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Text(
              resource.resourceName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),

            const SizedBox(height: 10),

            // Posted/requested by
            Text(
              resource.resourceStatus == ResourceStatus.posted
                  ? "Posted by:"
                  : "Requested by:",
              style: Theme.of(context).textTheme.titleMedium,
            ),

            const SizedBox(height: 6),

            Text(
              "${owner!.deviceName} (${owner.uuid})",
              style: TextStyle(color: Colors.grey.shade700),
            ),

            const SizedBox(height: 6),

            Text(
              "Last seen: ${_timeAgo(owner.lastSeen)}",
              style: TextStyle(color: Colors.grey.shade700),
            ),

            const Divider(height: 30),

            // Resource details
            Text(
              "Description",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(resource.resourceDescription),

            const SizedBox(height: 16),

            Text(
              "Status: ${resource.resourceStatus.name}",
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 6),
            Text(
              "Created: ${_timeAgo(resource.createdAt)}",
              style: TextStyle(color: Colors.grey.shade700),
            ),

            const SizedBox(height: 30),

            // Chat button
            Center(
              child: ElevatedButton.icon(
                onPressed: () {}, // not implemented yet
                icon: const Icon(Icons.chat),
                label: const Text("Open Chat"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      );
    },
  );
}

  Future<void> _postResource(String description, String name) async {
    try {
      final database = await db;
      String userUuid = beacon.uuid;

      final newResource = Resource(
        resourceName: name,
        resourceStatus: ResourceStatus.posted,
        resourceId: const Uuid().v4(),
        resourceType: _selected,
        resourceDescription: description,
        createdAt: DateTime.now(),
        userUuid: userUuid,
      );

      await database.insert(
        'resources',
        newResource.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      for (final device in connectedDevices) {
        if (device.uuid == userUuid) continue;

        await beacon.sendMessage(
          device.endpointId,
          'RESOURCES',
          {'resources': [newResource.toMap()]},
        );
      }
    } catch (e) {
      debugPrint('Error posting resource: $e');
    }
  }

  Future<void> _requestResource(String description, String name) async {
    try {
      final database = await db;
      String userUuid = beacon.uuid;

      final newResource = Resource(
        resourceName: name,
        resourceStatus: ResourceStatus.requested,
        resourceId: const Uuid().v4(),
        resourceType: _selected,
        resourceDescription: description,
        createdAt: DateTime.now(),
        userUuid: userUuid,
      );

      await database.insert(
        'resources',
        newResource.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      for (final device in connectedDevices) {
        if (device.uuid == userUuid) continue;

        await beacon.sendMessage(
          device.endpointId,
          'RESOURCES',
          {'resources': [newResource.toMap()]},
        );
      }
    } catch (e) {
      debugPrint('Error posting resource: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Text('Share or request emergency resources')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: ResourceTabs(
              selected: _selected,
              onChanged: _changeTab,
            ),
          ),

          Expanded(
          child: RefreshIndicator(
          onRefresh: () async {
            await _init(); // reload everything
          },

            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionHeader(selected: _selected),
                const SizedBox(height: 16),
                PostRequestPanel(
                  onPost: (name, desc) {
                    debugPrint('Posting ${_labelFor(_selected)}: $name - $desc');
                    if (connectedDevices.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Join a cluster or wait for others to connect before posting resources.'),
                        ),
                      );
                      return;
                    }
                    _postResource(desc, name);
                  },
                  onRequest: (name, desc) {
                    debugPrint('Requesting ${_labelFor(_selected)}: $name - $desc');
                    if (connectedDevices.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Join a cluster or wait for others to connect before requesting resources.'),
                        ),
                      );
                      return;
                    }
                    _requestResource(desc, name);
                  },
                ),


                const SizedBox(height: 16),

                Text(
                  'Recent activity',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
  
              if (resources == null)
                const Center(child: CircularProgressIndicator())
              else
                RecentActivityList(
                items: resources!,
                onView: (resource) {
                  _showResourceDetails(context, resource);
                },
                selected: _selected
              ),
              ],
            ),
          )
          ),

        ],
      ),
    );
    
  }
}

// ======================= UI CLASSES BELOW (UNCHANGED) =======================
class PostRequestPanel extends StatefulWidget {
  const PostRequestPanel({
    super.key,
    required this.onPost,
    required this.onRequest,
  });

  final void Function(String name, String desc) onPost;
  final void Function(String name, String desc) onRequest;

  @override
  State<PostRequestPanel> createState() => _PostRequestPanelState();
}

class _PostRequestPanelState extends State<PostRequestPanel> {
  bool showPostForm = false;
  bool showRequestForm = false;

  final TextEditingController postNameCtrl = TextEditingController();
  final TextEditingController postDescCtrl = TextEditingController();

  final TextEditingController reqNameCtrl = TextEditingController();
  final TextEditingController reqDescCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------------- POST SECTION ----------------
            Text('Post Available Resource', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  setState(() {
                    showPostForm = !showPostForm;
                    showRequestForm = false; // close other form
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Post Resource'),
              ),
            ),

            if (showPostForm) ...[
              const SizedBox(height: 12),
              TextField(
                controller: postNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Resource Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: postDescCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Resource Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    widget.onPost(
                      postNameCtrl.text.trim(),
                      postDescCtrl.text.trim(),
                    );
                    postNameCtrl.clear();
                    postDescCtrl.clear();
                    setState(() => showPostForm = false);
                  },
                  child: const Text('Submit'),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ---------------- REQUEST SECTION ----------------
            Text('Request Resource', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    showRequestForm = !showRequestForm;
                    showPostForm = false; // close other form
                  });
                },
                icon: const Icon(Icons.send),
                label: const Text('Request Resource'),
              ),
            ),

            if (showRequestForm) ...[
              const SizedBox(height: 12),
              TextField(
                controller: reqNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Resource Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reqDescCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Describe what you need…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    widget.onRequest(
                      reqNameCtrl.text.trim(),
                      reqDescCtrl.text.trim(),
                    );
                    reqNameCtrl.clear();
                    reqDescCtrl.clear();
                    setState(() => showRequestForm = false);
                  },
                  child: const Text('Submit'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


class ResourceTabs extends StatelessWidget {
  const ResourceTabs({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final ResourceType selected;
  final ValueChanged<ResourceType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ResourceType>(
      segments: resourceTabOrder
          .map(
            (type) => ButtonSegment<ResourceType>(
              value: type,
              icon: Icon(type.icon),
              label: Text(type.label),
            ),
          )
          .toList(),
      selected: {selected},
      onSelectionChanged: (set) => onChanged(set.first),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.selected});
  final ResourceType selected;

  @override
  Widget build(BuildContext context) {
    final title = selected.label;
    final subtitle = selected.subtitle;
    final icon = selected.icon;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(child: Icon(icon)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _labelFor(ResourceType t) => t.label;

class ActivityItem {
  final String title;
  final String meta;
  const ActivityItem({required this.title, required this.meta});
}

class RecentActivityList extends StatelessWidget {
  const RecentActivityList({super.key, required this.items, this.onView,required this.selected});

  final void Function(Resource item)? onView;
  final List<Resource> items;
  final ResourceType selected;




  @override
  Widget build(BuildContext context) {
    final sortedItems = [...items].where((r) => r.resourceType == selected).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (sortedItems.isEmpty) {
      return const Center(
        child: Text('No recent activity'),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final a = sortedItems[i];
        return Card(
  elevation: 0,
  child: ListTile(
    onTap: onView == null ? null : () => onView!(a),  
    leading: const CircleAvatar(
      child: Icon(Icons.inventory_2_outlined),
    ),
    title: Text(a.resourceName),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(a.resourceDescription),
        Text(
          "Status: ${a.resourceStatus.name}",
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Text(
          _timeAgo(a.createdAt),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    ),
    trailing: onView == null
        ? null
        : const Icon(Icons.chevron_right), 
  ),
);

      },
    );
  }
}
