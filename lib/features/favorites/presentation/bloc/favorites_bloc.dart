import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nomowear/core/network/api_exception.dart';
import 'package:nomowear/core/utils/api_id_utils.dart';
import 'package:nomowear/features/favorites/data/wishlist_repository.dart';

// ─────────────────────────── Model ────────────────────────────────
class FavoriteItem extends Equatable {
  final String id;
  final String? wishlistItemId;
  final String title;
  final String subtitle;
  final String imageUrl;

  const FavoriteItem({
    required this.id,
    this.wishlistItemId,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
  });

  FavoriteItem copyWith({
    String? id,
    String? wishlistItemId,
    String? title,
    String? subtitle,
    String? imageUrl,
  }) {
    return FavoriteItem(
      id: id ?? this.id,
      wishlistItemId: wishlistItemId ?? this.wishlistItemId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  List<Object?> get props => [id, wishlistItemId, title, subtitle, imageUrl];
}

// ─────────────────────────── Events ───────────────────────────────
abstract class FavoritesEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadWishlistEvent extends FavoritesEvent {
  final bool forceRefresh;
  LoadWishlistEvent({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

class ToggleFavoriteEvent extends FavoritesEvent {
  final FavoriteItem item;
  ToggleFavoriteEvent(this.item);
  @override
  List<Object?> get props => [item];
}

class RemoveFavoriteEvent extends FavoritesEvent {
  final String itemId;
  RemoveFavoriteEvent(this.itemId);
  @override
  List<Object?> get props => [itemId];
}

/// Clears in-memory wishlist only (no API). Used on logout / APK update.
class ClearFavoritesEvent extends FavoritesEvent {}

// ─────────────────────────── State ────────────────────────────────
class FavoritesState extends Equatable {
  final List<FavoriteItem> items;
  final bool isLoading;
  final String? errorMessage;

  const FavoritesState({
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  bool isFavorite(String id) => items.any((e) => e.id == id);

  FavoritesState copyWith({
    List<FavoriteItem>? items,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return FavoritesState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [items, isLoading, errorMessage];
}

// ─────────────────────────── Bloc ─────────────────────────────────
class FavoritesBloc extends Bloc<FavoritesEvent, FavoritesState> {
  FavoritesBloc({WishlistRepository? repository})
      : _repository = repository ?? WishlistRepository(),
        super(const FavoritesState()) {
    on<LoadWishlistEvent>(_onLoadWishlist);
    on<ToggleFavoriteEvent>(_onToggleFavorite);
    on<RemoveFavoriteEvent>(_onRemoveFavorite);
    on<ClearFavoritesEvent>(_onClearFavorites);
  }

  final WishlistRepository _repository;
  Future<void>? _loadWishlistFuture;

  Future<void> _onClearFavorites(
    ClearFavoritesEvent event,
    Emitter<FavoritesState> emit,
  ) async {
    emit(const FavoritesState());
  }

  Future<void> _onLoadWishlist(
    LoadWishlistEvent event,
    Emitter<FavoritesState> emit,
  ) async {
    // Reuse loaded wishlist when returning to the screen.
    if (!event.forceRefresh && state.items.isNotEmpty) return;
    if (_loadWishlistFuture != null) {
      await _loadWishlistFuture;
      return;
    }

    emit(state.copyWith(isLoading: true, clearError: true));
    _loadWishlistFuture = _loadWishlistOnce(emit);
    try {
      await _loadWishlistFuture;
    } finally {
      _loadWishlistFuture = null;
    }
  }

  Future<void> _loadWishlistOnce(Emitter<FavoritesState> emit) async {
    try {
      final items = await _repository.getWishlist();
      emit(state.copyWith(items: items, isLoading: false, clearError: true));
    } on ApiException catch (error) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: error.message,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Unable to load wishlist',
        ),
      );
    }
  }

  Future<void> _onToggleFavorite(
    ToggleFavoriteEvent event,
    Emitter<FavoritesState> emit,
  ) async {
    final existing = state.items.indexWhere((e) => e.id == event.item.id);
    final updatedList = List<FavoriteItem>.from(state.items);
    final isRemoving = existing >= 0;
    final existingItem = isRemoving ? state.items[existing] : null;

    if (isRemoving) {
      updatedList.removeAt(existing);
    } else {
      updatedList.add(event.item);
    }

    emit(state.copyWith(items: updatedList, clearError: true));

    if (!_shouldSyncWithApi(event.item.id)) return;

    try {
      if (isRemoving) {
        await _repository.removeFavorite(
          existingItem ?? event.item,
        );
      } else {
        final wishlistItemId =
            await _repository.addToWishlist(event.item.id);
        if (wishlistItemId != null) {
          final index = updatedList.indexWhere((e) => e.id == event.item.id);
          if (index >= 0) {
            updatedList[index] = event.item.copyWith(
              wishlistItemId: wishlistItemId,
            );
            emit(state.copyWith(items: updatedList, clearError: true));
          }
        }
      }
    } on ApiException catch (error) {
      emit(_revertToggle(event.item, isRemoving, error.message));
    } catch (_) {
      emit(_revertToggle(event.item, isRemoving, 'Unable to update wishlist'));
    }
  }

  Future<void> _onRemoveFavorite(
    RemoveFavoriteEvent event,
    Emitter<FavoritesState> emit,
  ) async {
    final previousItems = state.items;
    FavoriteItem? removedItem;
    for (final item in previousItems) {
      if (item.id == event.itemId) {
        removedItem = item;
        break;
      }
    }

    final updatedList =
        previousItems.where((e) => e.id != event.itemId).toList();
    emit(state.copyWith(items: updatedList, clearError: true));

    if (removedItem == null || !_shouldSyncWithApi(removedItem.id)) return;

    try {
      await _repository.removeFavorite(removedItem);
    } on ApiException catch (error) {
      final restored = List<FavoriteItem>.from(updatedList)..add(removedItem);
      emit(
        state.copyWith(
          items: restored,
          errorMessage: error.message,
        ),
      );
    } catch (_) {
      final restored = List<FavoriteItem>.from(updatedList)..add(removedItem);
      emit(
        state.copyWith(
          items: restored,
          errorMessage: 'Unable to remove from wishlist',
        ),
      );
    }
  }

  FavoritesState _revertToggle(
    FavoriteItem item,
    bool wasRemoving,
    String message,
  ) {
    final updatedList = List<FavoriteItem>.from(state.items);
    if (wasRemoving) {
      updatedList.add(item);
    } else {
      updatedList.removeWhere((entry) => entry.id == item.id);
    }
    return state.copyWith(items: updatedList, errorMessage: message);
  }

  bool _shouldSyncWithApi(String id) => isApiUuid(id);
}
