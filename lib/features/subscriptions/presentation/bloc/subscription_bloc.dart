import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nomowear/core/network/api_exception.dart';
import 'package:nomowear/features/subscriptions/data/subscription_repository.dart';
import 'package:nomowear/features/subscriptions/presentation/bloc/subscription_state.dart';

export 'subscription_state.dart';

class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  SubscriptionBloc({SubscriptionRepository? repository})
      : _repository = repository ?? SubscriptionRepository(),
        super(SubscriptionInitial()) {
    on<LoadActiveSubscriptionEvent>(_onLoadActiveSubscription);
  }

  final SubscriptionRepository _repository;
  Future<void>? _loadActiveFuture;

  Future<void> _onLoadActiveSubscription(
    LoadActiveSubscriptionEvent event,
    Emitter<SubscriptionState> emit,
  ) async {
    if (!event.forceRefresh &&
        (state is SubscriptionActive || state is SubscriptionInactive)) {
      return;
    }
    if (_loadActiveFuture != null) {
      await _loadActiveFuture;
      return;
    }

    emit(SubscriptionLoading());
    _loadActiveFuture = _loadActiveSubscriptionOnce(event, emit);
    try {
      await _loadActiveFuture;
    } finally {
      _loadActiveFuture = null;
    }
  }

  Future<void> _loadActiveSubscriptionOnce(
    LoadActiveSubscriptionEvent event,
    Emitter<SubscriptionState> emit,
  ) async {
    try {
      final subscription = await _repository.getActiveSubscription(
        forceRefresh: event.forceRefresh,
      );

      if (subscription != null) {
        emit(SubscriptionActive(subscription));
      } else {
        emit(SubscriptionInactive());
      }
    } on ApiException catch (e) {
      emit(SubscriptionError(e.message));
    } catch (_) {
      emit(SubscriptionError(
        'Unable to load subscription. Please try again.',
      ));
    }
  }
}
