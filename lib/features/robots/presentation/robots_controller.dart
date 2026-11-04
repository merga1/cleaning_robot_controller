import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/preferences_service.dart';
import '../data/robots_repository_impl.dart';
import '../domain/robot_model.dart';
import '../domain/robots_repository.dart';

final robotsRepositoryProvider = Provider<RobotsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final prefs = ref.watch(preferencesServiceProvider);
  final config = ref.watch(appConfigProvider);

  return RobotsRepositoryImpl(dio: dio, prefs: prefs, config: config);
});

class RobotsState {
  final bool isLoading;
  final List<RobotModel> robots;
  final RobotModel? activeRobot;
  final String? errorMessage;

  const RobotsState({
    this.isLoading = false,
    this.robots = const [],
    this.activeRobot,
    this.errorMessage,
  });

  RobotsState copyWith({
    bool? isLoading,
    List<RobotModel>? robots,
    RobotModel? activeRobot,
    String? errorMessage,
  }) {
    return RobotsState(
      isLoading: isLoading ?? this.isLoading,
      robots: robots ?? this.robots,
      activeRobot: activeRobot ?? this.activeRobot,
      errorMessage: errorMessage,
    );
  }
}

class RobotsController extends Notifier<RobotsState> {
  @override
  RobotsState build() {
    Future.microtask(() => loadRobots());
    return const RobotsState();
  }

  RobotsRepository get _repository => ref.read(robotsRepositoryProvider);

  Future<void> loadRobots() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _repository.getAuthorizedRobots();
      final savedId = _repository.getActiveRobotId();

      RobotModel? selected;
      if (savedId != null && list.any((r) => r.id == savedId)) {
        selected = list.firstWhere((r) => r.id == savedId);
      } else if (list.isNotEmpty) {
        selected = list.first; // MOB-ROB-003
        await _repository.saveActiveRobotId(selected.id);
      }

      state = state.copyWith(
        isLoading: false,
        robots: list,
        activeRobot: selected,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> selectRobot(RobotModel robot) async {
    await _repository.saveActiveRobotId(robot.id);
    state = state.copyWith(activeRobot: robot);
  }

  void updateActiveRobotFromLive(RobotModel updated) {
    if (state.activeRobot?.id == updated.id) {
      state = state.copyWith(activeRobot: updated);
    }
    final updatedList = state.robots.map((r) {
      return r.id == updated.id ? updated : r;
    }).toList();
    state = state.copyWith(robots: updatedList);
  }
}

final robotsControllerProvider =
    NotifierProvider<RobotsController, RobotsState>(RobotsController.new);
