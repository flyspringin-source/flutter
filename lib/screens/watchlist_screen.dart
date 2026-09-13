import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/watchlist_stock.dart';
import '../state/watchlist_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/add_scrip_sheet.dart';
import '../widgets/scrip_detail_sheet.dart';

class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key, this.active = true});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final watchlist = context.read<WatchlistController>();
    return ListenableBuilder(
      listenable: active ? watchlist : Listenable.merge([]),
      builder: (context, _) => _WatchlistBody(
        colors: colors,
        watchlist: watchlist,
      ),
    );
  }
}

class _WatchlistBody extends StatelessWidget {
  const _WatchlistBody({required this.colors, required this.watchlist});

  final AppColors colors;
  final WatchlistController watchlist;

  @override
  Widget build(BuildContext context) {
    final stocks = watchlist.stocks;
    return Column(
      children: [
        _WatchlistTabs(watchlist: watchlist),
        Expanded(
          child: stocks.isEmpty
              ? _EmptyWatchlist(
                  onAdd: () => showAddScripSheet(context),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 20),
                  itemCount: stocks.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: colors.border,
                  ),
                  itemBuilder: (context, index) {
                    final stock = stocks[index];
                    return Dismissible(
                      key: ValueKey('${watchlist.current.id}-${stock.token}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: AppColors.loss.withValues(alpha: 0.16),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(Icons.delete_outline, color: AppColors.loss),
                      ),
                      onDismissed: (_) => watchlist.removeScrip(stock.token),
                      child: _WatchlistTile(stock: stock),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _WatchlistTabs extends StatelessWidget {
  const _WatchlistTabs({required this.watchlist});

  final WatchlistController watchlist;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < watchlist.tabs.length; i++)
                    _TabChip(
                      label: watchlist.tabs[i].name,
                      selected: i == watchlist.selectedIndex,
                      canDelete: watchlist.tabs.length > 1,
                      onTap: () => watchlist.selectTab(i),
                      onLongPress: () => _editTab(context, i),
                      onDelete: () => _confirmDeleteTab(context, i),
                    ),
                  IconButton(
                    tooltip: 'Add watchlist',
                    onPressed: watchlist.tabs.length >= WatchlistController.maxTabs
                        ? null
                        : () => _addTab(context),
                    icon: const Icon(Icons.add, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Add scrip',
            onPressed: () => showAddScripSheet(context),
            icon: const Icon(Icons.search),
          ),
        ],
      ),
    );
  }

  Future<void> _addTab(BuildContext context) async {
    final suggested = WatchlistController.defaultTabName(
      watchlist.tabs.length + 1,
    );
    final controller = TextEditingController(text: suggested);
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: suggested.length,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New watchlist'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: 'Watchlist name'),
            onSubmitted: (_) => Navigator.pop(context, true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    final name = controller.text;
    controller.dispose();
    if (confirmed == true) {
      watchlist.addTab(name);
    }
  }

  Future<void> _confirmDeleteTab(BuildContext context, int index) async {
    if (watchlist.tabs.length <= 1) {
      return;
    }
    final name = watchlist.tabs[index].name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete watchlist?'),
          content: Text('Remove "$name" and its scrips?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      watchlist.removeTab(index);
    }
  }

  Future<void> _editTab(BuildContext context, int index) async {
    final current = watchlist.tabs[index].name;
    final controller = TextEditingController(text: current);
    final action = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Watchlist'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Name'),
          ),
          actions: [
            if (watchlist.tabs.length > 1)
              TextButton(
                onPressed: () => Navigator.pop(context, 'delete'),
                child: const Text('Delete'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (action == 'delete') {
      watchlist.removeTab(index);
    } else if (action == 'save') {
      watchlist.renameTab(index, controller.text);
    }
    controller.dispose();
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.canDelete,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
  });

  final String label;
  final bool selected;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: selected ? AppColors.accent.withValues(alpha: 0.14) : colors.surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? AppColors.accent : colors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.accent : colors.textSecondary,
                  ),
                ),
                if (selected && canDelete) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onDelete,
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: selected ? AppColors.accent : colors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyWatchlist extends StatelessWidget {
  const _EmptyWatchlist({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No scrips in this watchlist',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.search),
              label: const Text('Add scrip'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WatchlistTile extends StatelessWidget {
  const _WatchlistTile({required this.stock});

  final WatchlistStock stock;

  @override
  Widget build(BuildContext context) {
    final color = stock.isUp ? AppColors.profit : AppColors.loss;
    final colors = AppColors.of(context);
    return InkWell(
      onTap: () => showScripDetailSheet(context, stock.token),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stock.symbol,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${stock.exchange}  ·  ${stock.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: colors.textMuted),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatPrice(stock.ltp),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatSigned(stock.change)}  (${formatSigned(stock.changePercent)}%)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
