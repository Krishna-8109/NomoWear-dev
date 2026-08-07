class FilterOptions {
  const FilterOptions({
    required this.age,
    required this.gender,
  });

  final List<String> age;
  final List<String> gender;

  bool get isEmpty => age.isEmpty && gender.isEmpty;

  factory FilterOptions.fromJson(Map<String, dynamic> json) {
    return FilterOptions(
      age: _stringList(json['age']),
      gender: _stringList(json['gender']),
    );
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }
}
