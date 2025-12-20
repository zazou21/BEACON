import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/resource.dart';
import '../models/device.dart';
import '../viewmodels/resource_viewmodel.dart';
import 'package:beacon_project/services/text_to_speech.dart';
import 'package:beacon_project/screens/chat_page.dart';

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

class ResourcePage extends StatelessWidget {
  const ResourcePage({super.key,this.viewModel});
  final ResourceViewModel? viewModel;

  @override
  Widget build(BuildContext context) {

    return ChangeNotifierProvider(
      create: (_) => viewModel ?? (ResourceViewModel()..init()),
      child: Consumer<ResourceViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            appBar: AppBar(
              actions: [
                TtsButton(resourceViewModel: viewModel),
              ],
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: ResourceTabs(
                    selected: viewModel.selectedTab,
                    onChanged: viewModel.changeTab,
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: viewModel.init,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _SectionHeader(selected: viewModel.selectedTab),
                        const SizedBox(height: 16),
                        PostRequestPanel(
                          onPost: (name, desc) {
                            if (viewModel.connectedDevices.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Join a cluster or wait for others to connect before posting resources.',
                                  ),
                                ),
                              );
                              return;
                            }
                            viewModel.postResource(name, desc);
                          },
                          onRequest: (name, desc) {
                            if (viewModel.connectedDevices.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Join a cluster or wait for others to connect before requesting resources.',
                                  ),
                                ),
                              );
                              return;
                            }
                            viewModel.requestResource(name, desc);
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Recent activity',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        viewModel.isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : RecentActivityList(
                                items: viewModel.resources,
                                onView: (resource) {
                                  _showResourceDetails(
                                    context,
                                    resource,
                                    viewModel
                                  );
                                },
                                selected: viewModel.selectedTab,
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showResourceDetails(
    BuildContext context,
    Resource resource,
    ResourceViewModel? viewModel,
  ) {
    final Device owner = viewModel!.connectedDevices.firstWhere(
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
                  onPressed: () {
                    if (owner.uuid == viewModel!.beacon!.uuid) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cannot chat with yourself.'),
                        ),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatPage(
                          deviceUuid: owner.uuid,   
                        ),
                      ),
                    );
                  }, 
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
}

// ======================= UI WIDGETS =======================

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
  void dispose() {
    postNameCtrl.dispose();
    postDescCtrl.dispose();
    reqNameCtrl.dispose();
    reqDescCtrl.dispose();
    super.dispose();
  }

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
                    showRequestForm = false;
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
                    showPostForm = false;
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

class RecentActivityList extends StatelessWidget {
  const RecentActivityList({
    super.key,
    required this.items,
    this.onView,
    required this.selected,
  });

  final void Function(Resource item)? onView;
  final List<Resource> items;
  final ResourceType selected;

  @override
  Widget build(BuildContext context) {
    final sortedItems = [...items]
        .where((r) => r.resourceType == selected)
        .toList()
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
            trailing: onView == null ? null : const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }
}
