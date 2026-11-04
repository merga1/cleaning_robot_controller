import 'robot_model.dart';

abstract class RobotsRepository {
  Future<List<RobotModel>> getAuthorizedRobots();
  Future<RobotModel> getRobotById(String id);
  Future<void> saveActiveRobotId(String id);
  String? getActiveRobotId();
}

