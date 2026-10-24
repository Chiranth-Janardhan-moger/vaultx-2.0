import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vaultx/core/storage/vault_storage_service.dart';
import 'package:vaultx/core/theme/app_theme.dart';
import 'package:vaultx/core/theme/happy_feedback.dart';
import 'package:vaultx/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:vaultx/features/vault/domain/vault_password_entry.dart';
import 'package:vaultx/features/vault/domain/vault_watchtower_engine.dart';

/// Maps category names to standard accent colors (matching WebStack and curated palette)
Color getCategoryColor(String category) {
  final clean = category.trim().toLowerCase();
  switch (clean) {
    case 'all':
      return AppColors.primaryBlue;
    case 'google':
      return const Color(0xFF4285F4);
    case 'banking':
    case 'bank':
    case 'finance':
      return const Color(0xFF10B981);
    case 'pins':
    case 'pin':
      return const Color(0xFF10B981);
    case 'social':
      return const Color(0xFF8B5CF6);
    case 'work':
    case 'office':
      return const Color(0xFFF59E0B);
    case 'entertainment':
    case 'media':
      return const Color(0xFFEC4899);
    case 'shopping':
      return const Color(0xFF06B6D4);
    case 'others':
      return const Color(0xFF64748B);
    case 'notes':
      return const Color(0xFF3B82F6);
    case 'favorites':
      return Colors.amber;
    default:
      const dynamicPalette = [
        Color(0xFF6366F1), // Indigo
        Color(0xFF3B82F6), // Blue
        Color(0xFF14B8A6), // Teal
        Color(0xFF06B6D4), // Cyan
        Color(0xFF10B981), // Green
        Color(0xFFF97316), // Orange
        Color(0xFFEC4899), // Pink
        Color(0xFF8B5CF6), // Purple
        Color(0xFFEF4444), // Red
        Color(0xFFEAB308), // Yellow
      ];
      final hash = clean.codeUnits.fold<int>(0, (prev, elem) => prev + elem);
      return dynamicPalette[hash % dynamicPalette.length];
  }
}

/// Redesigned category creation dialog with spacious padding and clean styling.
Future<String?> showAddCategoryDialog(
  BuildContext context,
  WidgetRef ref, {
  ValueChanged<String>? onCategoryAdded,
}) async {
  final textController = TextEditingController();
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final cardBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
  final inputBg = isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface;
  final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
  final mutedCol = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

  void submit(BuildContext dialogContext) {
    final trimmed = textController.text.trim();
    if (trimmed.isEmpty) return;
    ref.read(vaultPasswordsProvider.notifier).addCategory(trimmed);
    HapticFeedback.mediumImpact();
    if (onCategoryAdded != null) {
      onCategoryAdded(trimmed);
    }
    Navigator.of(dialogContext).pop(trimmed);
  }

  return showDialog<String>(
    context: context,
    builder: (ctx) {
      return Dialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderCol),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.label_outline_rounded,
                      color: AppColors.primaryBlue,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'New Category',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Create a tag to organize items',
                          style: TextStyle(
                            fontSize: 12,
                            color: mutedCol,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: textController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'e.g. Gaming, Finance, Crypto',
                  filled: true,
                  fillColor: inputBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderCol),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderCol),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                  ),
                ),
                onSubmitted: (_) => submit(ctx),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: mutedCol,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => submit(ctx),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        'Add',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Checks if a category tag is a protected system category (All, Favorites, PINs, Others)
bool isSystemCategoryTag(String category) {
  final clean = category.trim().toLowerCase();
  return clean == 'all' ||
      clean == 'favorites' ||
      clean == '★ favorites' ||
      clean == 'pins' ||
      clean == 'pin' ||
      clean == 'others';
}

/// Action sheet shown on long-press of a category tag, offering Edit and Delete options.
Future<void> showTagActionSheet(
  BuildContext context,
  WidgetRef ref,
  String category, {
  ValueChanged<String>? onRenamed,
  VoidCallback? onDeleted,
}) async {
  if (isSystemCategoryTag(category)) {
    unawaited(HapticFeedback.lightImpact());
    HappyFeedback.show(context, message: 'System tag "$category" cannot be modified');
    return;
  }

  unawaited(HapticFeedback.mediumImpact());
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final sheetBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
  final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
  final mutedCol = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
  final catColor = getCategoryColor(category);

  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      return Material(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: borderCol),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: catColor.withAlpha(isDark ? 40 : 25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: catColor.withAlpha(100), width: 1),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.label_rounded,
                        color: catColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Category Options',
                            style: TextStyle(
                              fontSize: 12,
                              color: mutedCol,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: borderCol),
                const SizedBox(height: 8),

                // Option 1: Edit Category
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.edit_rounded,
                      color: AppColors.primaryBlue,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Edit Category',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Rename this tag across all credentials',
                    style: TextStyle(fontSize: 12, color: mutedCol),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    showEditCategoryDialog(
                      context,
                      ref,
                      category,
                      onRenamed: onRenamed,
                    );
                  },
                ),

                // Option 2: Delete Category
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.rose500.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.rose500,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Delete Category',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.rose500,
                    ),
                  ),
                  subtitle: Text(
                    'Move items in this tag to Others and delete tag',
                    style: TextStyle(fontSize: 12, color: mutedCol),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    confirmDeleteCategoryDialog(
                      context,
                      ref,
                      category,
                      onDeleted: onDeleted,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Dialog to rename an existing category tag.
Future<void> showEditCategoryDialog(
  BuildContext context,
  WidgetRef ref,
  String oldCategory, {
  ValueChanged<String>? onRenamed,
}) async {
  final textController = TextEditingController(text: oldCategory);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final cardBg = isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
  final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
  final mutedCol = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
  final inputBg = isDark ? AppColors.darkInputSurface : AppColors.lightInputSurface;

  void submit(BuildContext dialogCtx) {
    final newName = textController.text.trim();
    if (newName.isEmpty) return;
    if (newName != oldCategory) {
      ref.read(vaultPasswordsProvider.notifier).renameCategory(oldCategory, newName);
      HapticFeedback.mediumImpact();
      HappyFeedback.show(context, message: 'Tag renamed to "$newName"');
      onRenamed?.call(newName);
    }
    Navigator.of(dialogCtx).pop();
  }

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      return Dialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderCol),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.edit_rounded,
                      color: AppColors.primaryBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Edit Tag',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Rename tag across all items',
                          style: TextStyle(fontSize: 12, color: mutedCol),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: textController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Tag Name',
                  hintText: 'e.g. Work, Banking, Google',
                  filled: true,
                  fillColor: inputBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderCol),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderCol),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                  ),
                ),
                onSubmitted: (_) => submit(dialogCtx),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    child: Text('Cancel', style: TextStyle(color: mutedCol)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => submit(dialogCtx),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Confirmation dialog to delete a category tag and reassign its entries to Others.
Future<void> confirmDeleteCategoryDialog(
  BuildContext context,
  WidgetRef ref,
  String category, {
  VoidCallback? onDeleted,
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Delete "$category"?'),
      content: const Text(
        'Items under this category will be moved to "Others". This category tag will be removed.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.rose500,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            ref.read(vaultPasswordsProvider.notifier).deleteCategory(category);
            unawaited(HapticFeedback.heavyImpact());
            Navigator.of(ctx).pop();
            HappyFeedback.show(context, message: 'Category "$category" deleted');
            onDeleted?.call();
          },
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

/// Supported sort orders for the credential vault.
enum VaultSortOption {
  recentlyModified('Recently Modified', Icons.access_time_rounded),
  recentlyCreated('Recently Created', Icons.history_rounded),
  alphabetical('Alphabetical (A–Z)', Icons.sort_by_alpha_rounded),
  strength('Strength (Weakest First)', Icons.health_and_safety_rounded);

  final String label;
  final IconData icon;
  const VaultSortOption(this.label, this.icon);
}

class VaultPasswordsState {
  final List<VaultPasswordEntry> allEntries;
  final String searchQuery;
  final String selectedCategory;
  final List<String> customCategories;
  final List<String> deletedCategories;
  final VaultSortOption activeSortOption;

  static const List<String> defaultCategories = [
    'All',
    'Google',
    'Banking',
    'Social',
    'Work',
    'Entertainment',
    'Shopping',
    'PINs',
    'Others',
  ];

  static const List<String> entryCategories = [
    'Google',
    'Banking',
    'Social',
    'Work',
    'Entertainment',
    'Shopping',
    'PINs',
    'Others',
  ];

  const VaultPasswordsState({
    this.allEntries = const [],
    this.searchQuery = '',
    this.selectedCategory = 'All',
    this.customCategories = const [],
    this.deletedCategories = const [],
    this.activeSortOption = VaultSortOption.recentlyModified,
  });

  List<VaultPasswordEntry> get activeEntries =>
      allEntries.where((e) => !e.isDeleted).toList();

  List<String> get allCategories {
    final list = <String>['All', ...customCategories];
    for (final c in defaultCategories) {
      if (!list.any((existing) => existing.toLowerCase() == c.toLowerCase()) &&
          !deletedCategories.any((del) => del.toLowerCase() == c.toLowerCase())) {
        list.add(c);
      }
    }
    return list;
  }

  List<VaultPasswordEntry> get filteredEntries {
    final list = allEntries.where((entry) {
      if (entry.isDeleted) return false;

      final sel = selectedCategory.trim().toLowerCase();
      final entryCat = entry.category.trim().toLowerCase();

      final isFavFilter = sel.contains('fav');
      if (isFavFilter) return entry.isFavorite;

      final matchesCategory = sel == 'all'
          ? true
          : sel == 'others'
              ? (entryCat == 'others' ||
                  !defaultCategories.any((c) => c.toLowerCase() == entryCat))
              : (sel == 'pins' || sel == 'pin')
                  ? (entry.hasPin || entry.isPinOnly || entryCat == 'pins' || entryCat == 'pin')
                  : (entryCat == sel || (sel == 'banking' && entryCat == 'bank'));

      final query = searchQuery.trim().toLowerCase();
      final matchesSearch = query.isEmpty ||
          entry.title.toLowerCase().contains(query) ||
          entry.username.toLowerCase().contains(query) ||
          entry.email.toLowerCase().contains(query) ||
          entry.category.toLowerCase().contains(query);

      return matchesCategory && matchesSearch;
    }).toList();

    // Sort entries: Pin favorites to top unless already in the dedicated favorites tab
    list.sort((a, b) {
      final isFavTab = selectedCategory == '★ Favorites' || selectedCategory == 'Favorites';
      if (!isFavTab && a.isFavorite != b.isFavorite) {
        return a.isFavorite ? -1 : 1;
      }

      switch (activeSortOption) {
        case VaultSortOption.recentlyModified:
          return b.updatedAt.compareTo(a.updatedAt);
        case VaultSortOption.recentlyCreated:
          return b.createdAt.compareTo(a.createdAt);
        case VaultSortOption.alphabetical:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case VaultSortOption.strength:
          final aEntropy = (a.isSecureNote || a.isPinOnly) ? 999.0 : VaultWatchtowerEngine.calculateEntropy(a.password);
          final bEntropy = (b.isSecureNote || b.isPinOnly) ? 999.0 : VaultWatchtowerEngine.calculateEntropy(b.password);
          return aEntropy.compareTo(bEntropy);
      }
    });

    return list;
  }

  VaultPasswordsState copyWith({
    List<VaultPasswordEntry>? allEntries,
    String? searchQuery,
    String? selectedCategory,
    List<String>? customCategories,
    List<String>? deletedCategories,
    VaultSortOption? activeSortOption,
  }) {
    return VaultPasswordsState(
      allEntries: allEntries ?? this.allEntries,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      customCategories: customCategories ?? this.customCategories,
      deletedCategories: deletedCategories ?? this.deletedCategories,
      activeSortOption: activeSortOption ?? this.activeSortOption,
    );
  }
}

class VaultPasswordsNotifier extends StateNotifier<VaultPasswordsState> {
  final Ref? ref;
  final VaultStorageService _storage;

  VaultPasswordsNotifier({this.ref, VaultStorageService? storage})
      : _storage = storage ?? VaultStorageService(),
        super(const VaultPasswordsState()) {
    if (ref != null) {
      final authState = ref!.read(authSessionProvider);
      if (authState.isAuthenticated && authState.activeMasterKey != null) {
        loadEntries(authState.activeMasterKey!);
      }

      ref!.listen<AuthSessionState>(authSessionProvider, (prev, next) {
        if (next.isAuthenticated && next.activeMasterKey != null) {
          loadEntries(next.activeMasterKey!);
        } else if (prev?.isAuthenticated == true && !next.isAuthenticated) {
          state = const VaultPasswordsState();
        }
      });
    }
  }

  Future<void> loadEntries(List<int> masterKey) async {
    final entries = await _storage.loadPasswords(masterKey);
    final categories = await _storage.loadCustomCategories();
    final deleted = await _storage.loadDeletedCategories();
    state = state.copyWith(
      allEntries: entries,
      customCategories: categories,
      deletedCategories: deleted,
    );
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSelectedCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  void addCategory(String category) {
    final trimmed = category.trim();
    if (trimmed.isEmpty) return;
    if (!state.allCategories.any((c) => c.toLowerCase() == trimmed.toLowerCase())) {
      final updated = [...state.customCategories, trimmed];
      final updatedDeleted = state.deletedCategories
          .where((c) => c.toLowerCase() != trimmed.toLowerCase())
          .toList();
      state = state.copyWith(
        customCategories: updated,
        deletedCategories: updatedDeleted,
      );
      _storage.saveCustomCategories(updated);
      _storage.saveDeletedCategories(updatedDeleted);
    }
  }

  void renameCategory(String oldCat, String newCat) {
    final oldTrimmed = oldCat.trim();
    final newTrimmed = newCat.trim();
    if (newTrimmed.isEmpty || oldTrimmed.toLowerCase() == newTrimmed.toLowerCase()) return;

    // 1. Update deletedCategories & customCategories:
    final updatedDeleted = [...state.deletedCategories];
    if (VaultPasswordsState.defaultCategories.any((c) => c.toLowerCase() == oldTrimmed.toLowerCase())) {
      if (!updatedDeleted.any((c) => c.toLowerCase() == oldTrimmed.toLowerCase())) {
        updatedDeleted.add(oldTrimmed);
      }
    }

    final updatedCustom = state.customCategories
        .where((c) => c.toLowerCase() != oldTrimmed.toLowerCase())
        .toList();
    if (!updatedCustom.any((c) => c.toLowerCase() == newTrimmed.toLowerCase()) &&
        !VaultPasswordsState.defaultCategories.any((c) => c.toLowerCase() == newTrimmed.toLowerCase())) {
      updatedCustom.add(newTrimmed);
    }
    updatedDeleted.removeWhere((c) => c.toLowerCase() == newTrimmed.toLowerCase());

    // 2. Update entries that use oldCat:
    final updatedEntries = state.allEntries.map((e) {
      if (e.category.trim().toLowerCase() == oldTrimmed.toLowerCase()) {
        final updated = e.copyWith(
          category: newTrimmed,
          updatedAt: DateTime.now(),
        );
        _persistEntry(updated);
        return updated;
      }
      return e;
    }).toList();

    // 3. Update selectedCategory if it was oldCat:
    final newSelected = state.selectedCategory.toLowerCase() == oldTrimmed.toLowerCase()
        ? newTrimmed
        : state.selectedCategory;

    state = state.copyWith(
      customCategories: updatedCustom,
      deletedCategories: updatedDeleted,
      allEntries: updatedEntries,
      selectedCategory: newSelected,
    );
    _storage.saveCustomCategories(updatedCustom);
    _storage.saveDeletedCategories(updatedDeleted);
  }

  void deleteCategory(String category) {
    final catTrimmed = category.trim();
    if (catTrimmed.isEmpty || catTrimmed.toLowerCase() == 'all') return;

    // 1. Track deletion:
    final updatedDeleted = [...state.deletedCategories];
    if (VaultPasswordsState.defaultCategories.any((c) => c.toLowerCase() == catTrimmed.toLowerCase())) {
      if (!updatedDeleted.any((c) => c.toLowerCase() == catTrimmed.toLowerCase())) {
        updatedDeleted.add(catTrimmed);
      }
    }

    final updatedCustom = state.customCategories
        .where((c) => c.toLowerCase() != catTrimmed.toLowerCase())
        .toList();

    // 2. Reassign entries with this category to 'Others':
    final updatedEntries = state.allEntries.map((e) {
      if (e.category.trim().toLowerCase() == catTrimmed.toLowerCase()) {
        final updated = e.copyWith(
          category: 'Others',
          updatedAt: DateTime.now(),
        );
        _persistEntry(updated);
        return updated;
      }
      return e;
    }).toList();

    // 3. Reset selectedCategory if it was this category:
    final newSelected = state.selectedCategory.toLowerCase() == catTrimmed.toLowerCase()
        ? 'All'
        : state.selectedCategory;

    state = state.copyWith(
      customCategories: updatedCustom,
      deletedCategories: updatedDeleted,
      allEntries: updatedEntries,
      selectedCategory: newSelected,
    );
    _storage.saveCustomCategories(updatedCustom);
    _storage.saveDeletedCategories(updatedDeleted);
  }

  void addPassword(VaultPasswordEntry entry) {
    final trimmedCat = entry.category.trim();
    final updatedCustom = [...state.customCategories];
    if (trimmedCat.isNotEmpty &&
        !state.allCategories.any((c) => c.toLowerCase() == trimmedCat.toLowerCase())) {
      updatedCustom.add(trimmedCat);
    }
    final updatedDeleted = state.deletedCategories
        .where((c) => c.toLowerCase() != trimmedCat.toLowerCase())
        .toList();
    state = state.copyWith(
      allEntries: [entry, ...state.allEntries],
      customCategories: updatedCustom,
      deletedCategories: updatedDeleted,
    );
    _persistEntry(entry);
    _storage.saveCustomCategories(updatedCustom);
    _storage.saveDeletedCategories(updatedDeleted);
  }

  void updatePassword(VaultPasswordEntry updated) {
    final updatedList = state.allEntries.map((e) {
      return e.id == updated.id ? updated : e;
    }).toList();
    state = state.copyWith(allEntries: updatedList);
    _persistEntry(updated);
  }

  void deletePassword(String id) {
    VaultPasswordEntry? tombstone;
    final updatedList = state.allEntries.map((e) {
      if (e.id == id) {
        tombstone = e.copyWith(isDeleted: true, updatedAt: DateTime.now());
        return tombstone!;
      }
      return e;
    }).toList();
    state = state.copyWith(allEntries: updatedList);
    if (tombstone != null) {
      _persistEntry(tombstone!);
    } else {
      _storage.deletePassword(id);
    }
  }

  void setSortOption(VaultSortOption sort) {
    state = state.copyWith(activeSortOption: sort);
  }

  void toggleFavorite(String id) {
    VaultPasswordEntry? updatedEntry;
    final updatedList = state.allEntries.map((e) {
      if (e.id == id) {
        updatedEntry = e.copyWith(
          isFavorite: !e.isFavorite,
          updatedAt: DateTime.now(),
        );
        return updatedEntry!;
      }
      return e;
    }).toList();

    state = state.copyWith(allEntries: updatedList);
    if (updatedEntry != null) {
      _persistEntry(updatedEntry!);
    }
  }

  void saveEntry(VaultPasswordEntry entry) {
    if (state.allEntries.any((e) => e.id == entry.id)) {
      updatePassword(entry);
    } else {
      addPassword(entry);
    }
  }

  void saveAll(List<VaultPasswordEntry> entries) {
    state = state.copyWith(allEntries: entries);
    final key = ref?.read(authSessionProvider).activeMasterKey;
    if (key != null) {
      _storage.saveAllPasswords(entries, key);
    }
  }

  void _persistEntry(VaultPasswordEntry entry) {
    final key = ref?.read(authSessionProvider).activeMasterKey;
    if (key != null) {
      _storage.savePassword(entry, key);
    }
  }
}

final vaultPasswordsProvider =
    StateNotifierProvider<VaultPasswordsNotifier, VaultPasswordsState>((ref) {
  final storage = ref.watch(vaultStorageServiceProvider);
  return VaultPasswordsNotifier(ref: ref, storage: storage);
});
