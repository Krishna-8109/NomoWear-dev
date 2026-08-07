import 'package:nomowear/features/plans/data/models/plan_category.dart';
import 'package:nomowear/features/plans/data/models/wardrobe_plan.dart';

class PlanCache {
  PlanCache._();

  static final PlanCache instance = PlanCache._();

  List<PlanCategory>? _categories;
  final Map<String, List<WardrobePlan>> _plansByCategoryId = {};

  List<PlanCategory>? get categories => _categories;

  List<WardrobePlan>? plansForCategory(String categoryId) =>
      _plansByCategoryId[categoryId];

  void setCategories(List<PlanCategory> categories) {
    _categories = List.unmodifiable(categories);
  }

  void setPlansForCategory(String categoryId, List<WardrobePlan> plans) {
    _plansByCategoryId[categoryId] = List.unmodifiable(plans);
  }

  void clear() {
    _categories = null;
    _plansByCategoryId.clear();
  }
}
