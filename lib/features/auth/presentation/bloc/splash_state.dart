import 'package:equatable/equatable.dart';

enum SplashDestination { login, home }

abstract class SplashState extends Equatable {
  @override
  List<Object?> get props => [];
}

class SplashInitial extends SplashState {}

class SplashLoaded extends SplashState {
  SplashLoaded(this.destination);

  final SplashDestination destination;

  @override
  List<Object?> get props => [destination];
}
