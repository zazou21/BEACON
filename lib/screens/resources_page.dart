import 'package:flutter/material.dart';

enum ResourceTab { medical, foodWater, shelter }

const List<ActivityItem> placeholder_recent_activity_list= [
  ActivityItem(title: 'Needed: Food & Water supplies • 1 km • 5 min ago', meta: ''),
  ActivityItem(title: 'Available: Food & Water supplies • 2 km • 10 min ago', meta: ''),
  ActivityItem(title: 'Needed: Food & Water supplies • 3 km • 15 min ago', meta: ''),
];

class ResourcePage extends StatefulWidget {
  const ResourcePage({super.key});
  @override
  State<ResourcePage> createState() => _ResourcePageState();
}

class _ResourcePageState extends State<ResourcePage> {
  ResourceTab _selected = ResourceTab.foodWater;

  void _changeTab(ResourceTab tab) {
    setState(() => _selected = tab);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Share or request emergency resources')),
      body: Column(
        children: [
          // Tabs component
          Padding(
            padding: const EdgeInsets.all(12),
            child: ResourceTabs(
              selected: _selected,
              onChanged: _changeTab,
            ),
          ),
          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
        
                _SectionHeader(selected: _selected),

                const SizedBox(height: 16),
              

               
                PostRequestPanel(
                  onPost: () {
                   
                    debugPrint('Post ${_labelFor(_selected)} tapped');
                  },
                  onRequest: () {
                  
                    debugPrint('Request ${_labelFor(_selected)} tapped');
                  },
                ),
            
                const SizedBox(height: 16),

               
                Text('Recent activity', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                RecentActivityList(items: placeholder_recent_activity_list),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class PostRequestPanel extends StatelessWidget {
  const PostRequestPanel({
    super.key,
    required this.onPost,
    required this.onRequest,
  });

  final VoidCallback onPost;
  final VoidCallback onRequest;

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
            Text('Post Available Resource', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPost,
                icon: const Icon(Icons.add),
                label: const Text('Post Resource'),
              ),
            ),
            const SizedBox(height: 20),
            Text('Request Resource', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            const TextField(
              decoration: InputDecoration(
                hintText: 'Describe what you need…',
                prefixIcon: Icon(Icons.link_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRequest,
                icon: const Icon(Icons.send),
                label: const Text('Request Resource'),
              ),
            ),
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

  final ResourceTab selected;
  final ValueChanged<ResourceTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ResourceTab>(
      segments: const [
        ButtonSegment(
          value: ResourceTab.medical,
          icon: Icon(Icons.medical_services_outlined),
          label: Text('Medical'),
        ),
        ButtonSegment(
          value: ResourceTab.foodWater,
          icon: Icon(Icons.restaurant_menu),
          label: Text('Food & Water'),
        ),
        ButtonSegment(
          value: ResourceTab.shelter,
          icon: Icon(Icons.home_outlined),
          label: Text('Shelter'),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (set) => onChanged(set.first),
    );
  }
}


class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.selected});
  final ResourceTab selected;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle, icon) = switch (selected) {
      ResourceTab.medical =>
        ('Medical', 'Medicine, first aid, transport', Icons.medical_services_outlined),
      ResourceTab.foodWater =>
        ('Food & Water', 'Food supplies, clean water, nutrition', Icons.restaurant_menu),
      ResourceTab.shelter =>
        ('Shelter', 'Temporary housing, blankets, tents', Icons.home_outlined),
    };

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
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

String _labelFor(ResourceTab t) => switch (t) {
      ResourceTab.medical => 'Medical',
      ResourceTab.foodWater => 'Food & Water',
      ResourceTab.shelter => 'Shelter',
    };


class ActivityItem {
  final String title;
  final String meta;     
  const ActivityItem({required this.title, required this.meta});
}

class RecentActivityList extends StatelessWidget {
  const RecentActivityList({super.key, required this.items, this.onView});
  
  final void Function(ActivityItem item)? onView;

  final List<ActivityItem> items;

    @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final a = items[i];
        return Card(
          elevation: 0,
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.inventory_2_outlined)),
            title: Text(a.title),
            subtitle: Text(a.meta),
            trailing: TextButton(onPressed: onView == null ? null : () => onView!(a), child: const Text('View')),
          ),
        );
      },
    );
  }
}

