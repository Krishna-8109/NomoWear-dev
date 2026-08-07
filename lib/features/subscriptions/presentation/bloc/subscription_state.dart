import 'package:equatable/equatable.dart';
import 'package:nomowear/features/subscriptions/data/models/active_subscription.dart';

abstract class SubscriptionEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadActiveSubscriptionEvent extends SubscriptionEvent {
  LoadActiveSubscriptionEvent({this.forceRefresh = false});

  final bool forceRefresh;

  @override
  List<Object?> get props => [forceRefresh];
}

abstract class SubscriptionState extends Equatable {
  @override
  List<Object?> get props => [];
}

class SubscriptionInitial extends SubscriptionState {}

class SubscriptionLoading extends SubscriptionState {}

class SubscriptionActive extends SubscriptionState {
  SubscriptionActive(this.subscription);

  final ActiveSubscription subscription;

  @override
  List<Object?> get props => [subscription];
}

class SubscriptionInactive extends SubscriptionState {}

class SubscriptionError extends SubscriptionState {
  SubscriptionError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
