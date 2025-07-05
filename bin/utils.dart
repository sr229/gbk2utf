import "dart:io";
import "dart:convert";
import "package:gbk2utf/converter.dart";

const String version = "0.0.1";
final gbkCodec = GbkCodec();

/// Creates backup of a file
Future<void> createBackup(String filePath, {bool verbose = false}) async {
  try {
    final file = File(filePath);
    final backupPath = "$filePath.bak";
    await file.copy(backupPath);

    if (verbose) {
      print("Backup created: $backupPath");
    }
  } catch (e) {
    print("Error creating backup for $filePath: $e");
  }
}

/// Renames a file from oldPath to newPath.
/// Usually, the filenames are the same, however, due to how they were encoded,
/// the file name may need to be changed to reflect the new encoding.
Future<void> renameFile(String oldPath, String newPath) async {
  try {
    final oldFile = File(oldPath);
    if (!await oldFile.exists()) {
      print("Error: Source file not found: $oldPath");
      return;
    }

    // There's a high chance even the file name is encoded in GBK, so we need to decode it
    // First let's get the file name from the old path
    final oldFileName = Uri.file(oldPath).pathSegments.last;

    // Then decode it using the GBK codec
    final decodedFileName = gbkCodec.decode(utf8.encode(oldFileName));

    // Create the new path with the decoded file name
    final newFullPath = Uri.directory(
      newPath,
    ).resolve(decodedFileName).toFilePath();

    // Only rename if the filename actually changed
    if (oldFileName != decodedFileName) {
      // Copy the file content to the new location
      await oldFile.copy(newFullPath);
      // Delete the original file
      await oldFile.delete();
      print("Renamed: $oldPath -> $newFullPath");
    } else {
      // If the filename didn't change, only copy the file if the destination is different
      if (oldPath != newFullPath && !await File(newFullPath).exists()) {
        await oldFile.copy(newFullPath);
      }
    }
  } catch (e) {
    print("Error renaming file from $oldPath to $newPath: $e");
  }
}

/// Process a single file or directory for filename renaming
Future<void> processRename(
  String path, {
  bool recursive = false,
  bool verbose = false,
}) async {
  final entityType = FileSystemEntity.typeSync(path);

  if (entityType == FileSystemEntityType.file) {
    // For files, get the directory and rename in place
    final file = File(path);
    final parent = file.parent.path;
    await renameFile(path, parent);
    if (verbose) {
      print("Processed file: $path");
    }
  } else if (entityType == FileSystemEntityType.directory) {
    // For directories, process all files
    final dir = Directory(path);
    final List<FileSystemEntity> entities = [];

    if (recursive) {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          entities.add(entity);
        }
      }
    } else {
      await for (final entity in dir.list()) {
        if (entity is File) {
          entities.add(entity);
        }
      }
    }

    // Sort to process parent directories first (avoids path issues)
    entities.sort((a, b) => a.path.length.compareTo(b.path.length));

    int processedCount = 0;
    for (final entity in entities) {
      final parent = Directory(entity.parent.path);
      await renameFile(entity.path, parent.path);
      processedCount++;
      if (verbose) {
        print("Processed file: ${entity.path}");
      }
    }

    if (verbose) {
      print("Processed $processedCount files in directory: $path");
    }
  } else {
    print("Warning: Path not found or inaccessible: $path");
  }
}

/// Collects files from paths, handling recursive directory traversal
Future<List<String>> collectFiles(
  List<String> paths, {
  bool recursive = false,
}) async {
  final List<String> files = [];

  for (final path in paths) {
    final entity = FileSystemEntity.typeSync(path);

    if (entity == FileSystemEntityType.file) {
      files.add(path);
    } else if (entity == FileSystemEntityType.directory) {
      final dir = Directory(path);
      if (recursive) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            files.add(entity.path);
          }
        }
      } else {
        await for (final entity in dir.list()) {
          if (entity is File) {
            files.add(entity.path);
          }
        }
      }
    } else {
      print("Warning: Path not found or inaccessible: $path");
    }
  }

  return files;
}
