import 'dart:io';

String normalize(String path) {
  return Uri.file(path).toFilePath(windows: false).replaceAll('\\', '/');
}

String resolvePath(String baseDir, String relativePath) {
  List<String> baseParts = baseDir.split('/');
  List<String> relParts = relativePath.split('/');
  
  for (String part in relParts) {
    if (part == '..') {
      if (baseParts.isNotEmpty) baseParts.removeLast();
    } else if (part != '.' && part.isNotEmpty) {
      baseParts.add(part);
    }
  }
  return baseParts.join('/');
}

void main() {
  final map = {
    "splash": "auth",
    "login": "auth",
    "otp": "auth",
    "success": "auth",
    "screenshot": "auth",
    "home": "home",
    "wardrobe": "wardrobe",
    "wardrobe_kit": "wardrobe",
    "product_details": "wardrobe",
    "cart": "cart",
    "delivery_location": "cart",
    "essentials_checkout": "checkout",
    "order_success": "checkout",
    "order_tracking": "checkout",
    "categories": "categories",
    "favorites": "favorites",
    "profile": "profile",
    "edit_profile": "profile",
    "about_us": "profile",
    "privacy_policy": "profile",
    "terms_conditions": "profile",
    "help_support": "profile",
    "membership_purchase": "profile",
    "notifications": "notifications"
  };

  Map<String, String> oldToNew = {};

  final uniqueFeatures = map.values.toSet();
  for (final feature in uniqueFeatures) {
    final dirs = [
      'lib/features/$feature/data/models',
      'lib/features/$feature/data/datasource',
      'lib/features/$feature/data/repository',
      'lib/features/$feature/domain/entities',
      'lib/features/$feature/domain/repository',
      'lib/features/$feature/domain/usecases',
      'lib/features/$feature/presentation/bloc',
      'lib/features/$feature/presentation/screens',
      'lib/features/$feature/presentation/widgets',
    ];
    for (var d in dirs) {
      Directory(d).createSync(recursive: true);
    }
  }

  final sampleDir = Directory('lib/features/sample');
  if (sampleDir.existsSync()) {
    sampleDir.deleteSync(recursive: true);
  }

  void moveFile(File file, String destPath) {
    String normalOld = normalize(file.path);
    String normalNew = normalize(destPath);
    oldToNew[normalOld] = normalNew;
    file.renameSync(destPath);
  }

  for (final screen in map.keys) {
    final feature = map[screen]!;
    final srcDir = Directory('lib/presentation/${screen}_screen');
    if (!srcDir.existsSync()) continue;

    final blocDir = Directory('${srcDir.path}/bloc');
    if (blocDir.existsSync()) {
      for (var file in blocDir.listSync()) {
        if (file is File) moveFile(file, 'lib/features/$feature/presentation/bloc/${file.uri.pathSegments.last}');
      }
    }
    
    final modelsDir = Directory('${srcDir.path}/models');
    if (modelsDir.existsSync()) {
      for (var file in modelsDir.listSync()) {
        if (file is File) moveFile(file, 'lib/features/$feature/data/models/${file.uri.pathSegments.last}');
      }
    }

    final widgetsDir = Directory('${srcDir.path}/widgets');
    if (widgetsDir.existsSync()) {
      for (var file in widgetsDir.listSync()) {
        if (file is File) moveFile(file, 'lib/features/$feature/presentation/widgets/${file.uri.pathSegments.last}');
      }
    }

    for (var file in srcDir.listSync()) {
      if (file is File && file.path.endsWith('.dart')) {
        moveFile(file, 'lib/features/$feature/presentation/screens/${file.uri.pathSegments.last}');
      }
    }
  }

  final presentationDir = Directory('lib/presentation');
  if (presentationDir.existsSync()) {
    try {
        presentationDir.deleteSync(recursive: true);
    } catch(e) {}
  }

  // Update imports
  final libDir = Directory('lib');
  final dartFiles = libDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  final importRegex = RegExp(r"(import|export)\s+['""](.*?)['""];");

  for (final file in dartFiles) {
    String content = file.readAsStringSync();
    String normalCurrent = normalize(file.path);
    
    String normalOldPath = normalCurrent;
    for (var entry in oldToNew.entries) {
      if (entry.value == normalCurrent) {
        normalOldPath = entry.key;
        break;
      }
    }

    List<String> oldPathParts = normalOldPath.split('/');
    oldPathParts.removeLast(); 
    String oldDir = oldPathParts.join('/');

    String newContent = content.replaceAllMapped(importRegex, (match) {
      String type = match.group(1)!;
      String importPath = match.group(2)!;
      
      if (importPath.startsWith('dart:')) return match.group(0)!;
      
      if (importPath.startsWith('package:nomowear/')) {
        String internalPath = importPath.replaceFirst('package:nomowear/', 'lib/');
        if (oldToNew.containsKey(internalPath)) {
            String newInternal = oldToNew[internalPath]!.replaceFirst('lib/', '');
            return "$type 'package:nomowear/$newInternal';";
        }
        return match.group(0)!;
      }

      if (importPath.startsWith('package:')) {
          return match.group(0)!;
      }

      String resolvedOldPath = resolvePath(oldDir, importPath);

      if (oldToNew.containsKey(resolvedOldPath)) {
        String newInternal = oldToNew[resolvedOldPath]!.replaceFirst('lib/', '');
        return "$type 'package:nomowear/$newInternal';";
      } else {
        if (resolvedOldPath.startsWith('lib/')) {
             String newInternal = resolvedOldPath.replaceFirst('lib/', '');
             return "$type 'package:nomowear/$newInternal';";
        }
      }
      return match.group(0)!;
    });

    if (newContent != content) {
      file.writeAsStringSync(newContent);
    }
  }

  print('Migration completed successfully!');
}
