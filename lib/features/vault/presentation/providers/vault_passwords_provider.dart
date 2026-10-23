import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vaultx/core/storage/vault_storage_service.dart';
import 'package:vaultx/core/theme/app_theme.dart';
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
    'Others',
  ];

  static const List<String> entryCategories = [
    'Google',
    'Banking',
    'Social',
    'Work',
    'Entertainment',
    'Shopping',
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
          final aEntropy = a.isSecureNote ? 999.0 : VaultWatchtowerEngine.calculateEntropy(a.password);
          final bEntropy = b.isSecureNote ? 999.0 : VaultWatchtowerEngine.calculateEntropy(b.password);
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
