import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vaultx/core/storage/vault_storage_service.dart';
import 'package:vaultx/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:vaultx/features/vault/domain/vault_password_entry.dart';
import 'package:vaultx/features/vault/domain/vault_watchtower_engine.dart';

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
  final VaultSortOption activeSortOption;

  static const List<String> defaultCategories = [
    'Email',
    'Instagram',
    'Bank',
    'GitHub',
    'Entertainment',
    'Social',
  ];

  const VaultPasswordsState({
    this.allEntries = const [],
    this.searchQuery = '',
    this.selectedCategory = 'All',
    this.customCategories = const [],
    this.activeSortOption = VaultSortOption.recentlyModified,
  });

  List<VaultPasswordEntry> get activeEntries =>
      allEntries.where((e) => !e.isDeleted).toList();

  List<String> get allCategories {
    final list = <String>[...customCategories];
    for (final c in defaultCategories) {
      if (!list.any((existing) => existing.toLowerCase() == c.toLowerCase())) {
        list.add(c);
      }
    }
    for (final entry in allEntries) {
      if (entry.isDeleted) continue;
      final c = entry.category.trim();
      if (c.isNotEmpty && !list.any((existing) => existing.toLowerCase() == c.toLowerCase())) {
        list.add(c);
      }
    }
    return list;
  }

  List<VaultPasswordEntry> get filteredEntries {
    final list = allEntries.where((entry) {
      if (entry.isDeleted) return false;

      final isFavFilter = selectedCategory == '★ Favorites' ||
          selectedCategory == 'Favorites';
      final matchesCategory = isFavFilter
          ? entry.isFavorite
          : (selectedCategory == 'All' ||
              entry.category.toLowerCase() == selectedCategory.toLowerCase());

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
    VaultSortOption? activeSortOption,
  }) {
    return VaultPasswordsState(
      allEntries: allEntries ?? this.allEntries,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      customCategories: customCategories ?? this.customCategories,
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
    state = state.copyWith(
      allEntries: entries,
      customCategories: categories,
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
      state = state.copyWith(customCategories: updated);
      _storage.saveCustomCategories(updated);
    }
  }

  void addPassword(VaultPasswordEntry entry) {
    final trimmedCat = entry.category.trim();
    final updatedCustom = [...state.customCategories];
    if (trimmedCat.isNotEmpty &&
        !state.allCategories.any((c) => c.toLowerCase() == trimmedCat.toLowerCase())) {
      updatedCustom.add(trimmedCat);
    }
    state = state.copyWith(
      allEntries: [entry, ...state.allEntries],
      customCategories: updatedCustom,
    );
    _persistEntry(entry);
    _storage.saveCustomCategories(updatedCustom);
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
