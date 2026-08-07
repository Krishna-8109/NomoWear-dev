final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

bool isApiUuid(String? value) {
  final id = value?.trim();
  if (id == null || id.isEmpty) return false;
  return _uuidPattern.hasMatch(id);
}
