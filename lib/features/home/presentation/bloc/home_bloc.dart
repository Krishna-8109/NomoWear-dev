import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

// Events
abstract class HomeEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class ChangeBottomNavEvent extends HomeEvent {
  final int index;
  ChangeBottomNavEvent(this.index);
  @override
  List<Object?> get props => [index];
}

// State
class HomeState extends Equatable {
  final int bottomNavIndex;

  const HomeState({this.bottomNavIndex = 0});

  HomeState copyWith({int? bottomNavIndex}) {
    return HomeState(bottomNavIndex: bottomNavIndex ?? this.bottomNavIndex);
  }

  @override
  List<Object?> get props => [bottomNavIndex];
}

// Bloc
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({int initialBottomNavIndex = 0})
      : super(HomeState(bottomNavIndex: initialBottomNavIndex)) {
    on<ChangeBottomNavEvent>((event, emit) {
      emit(state.copyWith(bottomNavIndex: event.index));
    });
  }
}
