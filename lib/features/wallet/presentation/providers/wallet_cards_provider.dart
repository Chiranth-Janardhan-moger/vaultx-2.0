import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:vaultx/core/storage/vault_storage_service.dart';
import 'package:vaultx/features/auth/presentation/providers/auth_session_provider.dart';
import 'package:vaultx/features/wallet/domain/wallet_card_entry.dart';

class WalletCardsState {
  final List<WalletCardEntry> allCards;
  final String searchQuery;
  final String selectedNetwork;

  const WalletCardsState({
    this.allCards = const [],
    this.searchQuery = '',
    this.selectedNetwork = 'All',
  });

  List<WalletCardEntry> get activeCards =>
      allCards.where((c) => !c.isDeleted).toList();

  List<WalletCardEntry> get filteredCards {
    return allCards.where((card) {
      if (card.isDeleted) return false;
      final matchesNetwork = selectedNetwork == 'All' ||
          card.network.toLowerCase() == selectedNetwork.toLowerCase();
      final query = searchQuery.trim().toLowerCase();
      final matchesSearch = query.isEmpty ||
          card.title.toLowerCase().contains(query) ||
          card.cardholderName.toLowerCase().contains(query) ||
          card.network.toLowerCase().contains(query) ||
          card.cardNumber.contains(query);
      return matchesNetwork && matchesSearch;
    }).toList();
  }

  WalletCardsState copyWith({
    List<WalletCardEntry>? allCards,
    String? searchQuery,
    String? selectedNetwork,
  }) {
    return WalletCardsState(
      allCards: allCards ?? this.allCards,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedNetwork: selectedNetwork ?? this.selectedNetwork,
    );
  }
}

class WalletCardsNotifier extends StateNotifier<WalletCardsState> {
  final Ref? ref;
  final VaultStorageService _storage;

  WalletCardsNotifier({this.ref, VaultStorageService? storage})
      : _storage = storage ?? VaultStorageService(),
        super(const WalletCardsState()) {
    if (ref != null) {
      final authState = ref!.read(authSessionProvider);
      if (authState.isAuthenticated && authState.activeMasterKey != null) {
        loadCards(authState.activeMasterKey!);
      }

      ref!.listen<AuthSessionState>(authSessionProvider, (prev, next) {
        if (next.isAuthenticated && next.activeMasterKey != null) {
          loadCards(next.activeMasterKey!);
        } else if (prev?.isAuthenticated == true && !next.isAuthenticated) {
          state = const WalletCardsState();
        }
      });
    }
  }

  Future<void> loadCards(List<int> masterKey) async {
    final cards = await _storage.loadCards(masterKey);
    state = state.copyWith(allCards: cards);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSelectedNetwork(String network) {
    state = state.copyWith(selectedNetwork: network);
  }

  void addCard(WalletCardEntry card) {
    state = state.copyWith(
      allCards: [card, ...state.allCards],
    );
    _persistCard(card);
  }

  void updateCard(WalletCardEntry updated) {
    final updatedList = state.allCards.map((c) {
      return c.id == updated.id ? updated : c;
    }).toList();
    state = state.copyWith(allCards: updatedList);
    _persistCard(updated);
  }

  void deleteCard(String id) {
    WalletCardEntry? tombstone;
    final updatedList = state.allCards.map((c) {
      if (c.id == id) {
        tombstone = c.copyWith(isDeleted: true, updatedAt: DateTime.now());
        return tombstone!;
      }
      return c;
    }).toList();
    state = state.copyWith(allCards: updatedList);
    if (tombstone != null) {
      _persistCard(tombstone!);
    } else {
      _storage.deleteCard(id);
    }
  }

  void saveCard(WalletCardEntry card) {
    if (state.allCards.any((c) => c.id == card.id)) {
      updateCard(card);
    } else {
      addCard(card);
    }
  }

  void saveAll(List<WalletCardEntry> cards) {
    state = state.copyWith(allCards: cards);
    final key = ref?.read(authSessionProvider).activeMasterKey;
    if (key != null) {
      _storage.saveAllCards(cards, key);
    }
  }

  void _persistCard(WalletCardEntry card) {
    final key = ref?.read(authSessionProvider).activeMasterKey;
    if (key != null) {
      _storage.saveCard(card, key);
    }
  }
}

final walletCardsProvider =
    StateNotifierProvider<WalletCardsNotifier, WalletCardsState>((ref) {
  final storage = ref.watch(vaultStorageServiceProvider);
  return WalletCardsNotifier(ref: ref, storage: storage);
});
