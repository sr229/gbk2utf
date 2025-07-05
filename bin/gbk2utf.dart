import "dart:io";
import "dart:convert";

import "package:args/args.dart";
import "package:gbk2utf/converter.dart";

const String version = "0.0.1";

ArgParser buildParser() {
  return ArgParser()
    ..addFlag(
      "help",
      abbr: "h",
      negatable: false,
      help: "Print this usage information.",
    )
    ..addFlag(
      "verbose",
      abbr: "v",
      negatable: false,
      help: "Show additional command output.",
    )
    ..addFlag("version", negatable: false, help: "Print the tool version.")
    ..addFlag(
      "backup",
      abbr: "b",
      negatable: false,
      help: "Create backup files before conversion.",
    )
    ..addFlag(
      "recursive",
      abbr: "r",
      negatable: false,
      help: "Process directories recursively.",
    )
    ..addFlag(
      "reverse",
      negatable: false,
      help: "Convert from UTF-8 to GBK instead of GBK to UTF-8.",
    )
    ..addOption(
      "output",
      abbr: "o",
      help: "Output directory (default: overwrite original files).",
    )
    ..addOption(
      "encoding",
      abbr: "e",
      defaultsTo: "gbk",
      allowed: ["gbk", "utf8"],
      help: "Source encoding (gbk or utf8).",
    );
}

void printUsage(ArgParser argParser) {
  print("Usage: dart gbk2utf.dart <flags> [files/directories]");
  print("\nConverts between GBK and UTF-8 encoded files.");
  print("\nOptions:");
  print(argParser.usage);
  print("\nExamples:");
  print(
    "  dart gbk2utf.dart file.txt                    # Convert GBK file to UTF-8",
  );
  print(
    "  dart gbk2utf.dart --reverse file.txt          # Convert UTF-8 file to GBK",
  );
  print(
    "  dart gbk2utf.dart -b -r /path/to/directory     # Recursively convert with backup",
  );
  print(
    "  dart gbk2utf.dart -o /output/dir file1.txt    # Convert to output directory",
  );
}

Future<void> convertFileEncoding(
  String filePath, {
  String? outputDir,
  bool reverse = false,
  bool verbose = false,
}) async {
  try {
    final file = File(filePath);
    if (!await file.exists()) {
      print("Error: File not found: $filePath");
      return;
    }

    if (verbose) {
      print("Processing: $filePath");
    }

    // Create GBK codec instance
    final gbkCodec = GbkCodec();

    // Read file as bytes
    final sourceBytes = await file.readAsBytes();
    List<int> convertedBytes;

    if (reverse) {
      // Convert UTF-8 to GBK
      try {
        // First decode as UTF-8 to verify it's valid UTF-8
        final utf8String = utf8.decode(sourceBytes);
        // Then encode to GBK using our codec
        convertedBytes = gbkCodec.encode(utf8String);
      } catch (e) {
        print("Error: File $filePath is not valid UTF-8: $e");
        return;
      }
    } else {
      // Convert GBK to UTF-8 (default)
      try {
        // Use our GBK codec to decode GBK to string
        final decodedString = gbkCodec.decode(sourceBytes);
        // Then encode as UTF-8
        convertedBytes = utf8.encode(decodedString);
      } catch (e) {
        print("Error converting GBK file $filePath: $e");
        return;
      }
    }

    // Determine output path
    String outputPath;
    if (outputDir != null) {
      // Extract just the filename from the full path
      final fileName = Uri.file(filePath).pathSegments.last;
      outputPath = Uri.directory(outputDir).resolve(fileName).toFilePath();

      if (verbose) {
        print("Output path: $outputPath");
      }

      // Ensure output directory exists
      final outputDirectory = Directory(outputDir);
      if (!await outputDirectory.exists()) {
        await outputDirectory.create(recursive: true);
        if (verbose) {
          print("Created output directory: $outputDir");
        }
      }
    } else {
      outputPath = filePath;
    }

    // Write converted content
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(convertedBytes);

    if (verbose) {
      final direction = reverse ? "UTF-8 -> GBK" : "GBK -> UTF-8";
      print("Converted ($direction): $filePath -> $outputPath");
    }
  } catch (e) {
    print("Error processing $filePath: $e");
  }
}

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

    await oldFile.rename(newPath);
  } catch (e) {
    print("Error renaming file from $oldPath to $newPath: $e");
  }
}

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

Future<void> main(List<String> arguments) async {
  final ArgParser argParser = buildParser();

  try {
    final ArgResults results = argParser.parse(arguments);

    // Handle help and version flags
    if (results.flag("help")) {
      printUsage(argParser);
      return;
    }

    if (results.flag("version")) {
      print("gbk2utf version: $version");
      return;
    }

    // Check if input paths are provided
    if (results.rest.isEmpty) {
      print("Error: No input files or directories specified.");
      print("");
      printUsage(argParser);
      exit(1);
    }

    // Get configuration
    final bool verbose = results.flag("verbose");
    final bool backup = results.flag("backup");
    final bool recursive = results.flag("recursive");
    final bool reverse = results.flag("reverse");
    final String? outputDir = results.option("output");
    final String encoding = results.option("encoding")!;

    if (verbose) {
      print("Configuration:");
      print('  Mode: ${reverse ? "UTF-8 to GBK" : "GBK to UTF-8"}');
      print("  Verbose: $verbose");
      print("  Backup: $backup");
      print("  Recursive: $recursive");
      print('  Output directory: ${outputDir ?? 'overwrite original'}');
      print("  Source encoding: $encoding");
      print("  Input paths: ${results.rest}");
      print("");
    }

    // Collect all files to process
    final files = await collectFiles(results.rest, recursive: recursive);

    if (files.isEmpty) {
      print("No files found to process.");
      return;
    }

    if (verbose) {
      print("Found ${files.length} file(s) to process.");
      print("");
    }

    // Process each file
    int successCount = 0;
    for (final filePath in files) {
      try {
        // Create backup if requested and not using output directory
        if (backup && outputDir == null) {
          await createBackup(filePath, verbose: verbose);
        }

        // Convert encoding
        await convertFileEncoding(
          filePath,
          outputDir: outputDir,
          reverse: reverse,
          verbose: verbose,
        );

        successCount++;
      } catch (e) {
        print("Error processing $filePath: $e");
      }
    }

    print(
      "Conversion completed. Successfully processed $successCount of ${files.length} file(s).",
    );
  } on FormatException catch (e) {
    print("Error: ${e.message}");
    print("");
    printUsage(argParser);
    exit(1);
  } catch (e) {
    print("Unexpected error: $e");
    exit(1);
  }
}
