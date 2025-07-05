import "dart:io";
import "dart:convert";

import "package:args/args.dart";
import "package:path/path.dart" show join, dirname, basename;
import "utils.dart";

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
    ..addOption(
      "output",
      abbr: "o",
      help: "Output directory (default: overwrite original files).",
    );
}

void printUsage(ArgParser argParser) {
  print("Usage: dart utf2gbk.dart <flags> [files/directories]");
  print("\nConverts UTF-8 encoded files to GBK.");
  print("\nOptions:");
  print(argParser.usage);
  print("\nExamples:");
  print(
    "  dart utf2gbk.dart file.txt                    # Convert UTF-8 file to GBK",
  );
  print(
    "  dart utf2gbk.dart -b /path/to/directory       # Convert with backup",
  );
  print(
    "  dart utf2gbk.dart -r /path/to/directory       # Recursively convert a directory",
  );
  print(
    "  dart utf2gbk.dart -o /output/dir file1.txt    # Convert to output directory",
  );
  print(
    "  dart gbk2utf.dart file.txt                    # Convert GBK file to UTF-8 (use gbk2utf)",
  );
}

Future<void> convertFileEncoding(
  String filePath, {
  String? outputDir,
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

    // Read file as bytes
    final sourceBytes = await file.readAsBytes();
    List<int> convertedBytes;

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

    // Determine output path
    String outputPath;

    if (outputDir != null) {
      // Extract just the filename from the full path
      final fileName = basename(filePath);

      // Preserve directory structure relative to input directory
      // First, determine the common base directory from the input paths
      final inputBaseDir = File(filePath).parent.path;

      // Calculate path segments to preserve directory structure
      String relativePath = "";

      // If the input path has subdirectories we want to preserve in the output
      if (inputBaseDir != dirname(filePath)) {
        // Get subdirectory structure to preserve
        final segments = dirname(filePath).split(Platform.pathSeparator);
        final baseSegments = inputBaseDir.split(Platform.pathSeparator);

        // Extract subdirectory path that needs to be preserved
        if (segments.length > baseSegments.length) {
          final preservedSegments = segments.sublist(baseSegments.length);
          relativePath = preservedSegments.join(Platform.pathSeparator);
        }
      }

      // Create target path preserving directory structure
      if (relativePath.isNotEmpty) {
        final targetDir = join(outputDir, relativePath);
        outputPath = join(targetDir, fileName);
      } else {
        outputPath = join(outputDir, fileName);
      }

      if (verbose) {
        print("Output path: $outputPath");
      }

      // Ensure output directory exists
      final outputDirectory = Directory(dirname(outputPath));
      if (!await outputDirectory.exists()) {
        await outputDirectory.create(recursive: true);
        if (verbose) {
          print("Created output directory: ${outputDirectory.path}");
        }
      }
    } else {
      // No output directory, just use the original path
      outputPath = filePath;
    }

    // Write converted content
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(convertedBytes);

    if (verbose) {
      print("Converted (UTF-8 -> GBK): $filePath -> $outputPath");
    }
  } catch (e) {
    print("Error processing $filePath: $e");
  }
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
      print("utf2gbk version: $version");
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
    final String? outputDir = results.option("output");

    if (verbose) {
      print("Configuration:");
      print("  Mode: UTF-8 to GBK");
      print("  Verbose: $verbose");
      print("  Backup: $backup");
      print("  Recursive: $recursive");
      print('  Output directory: ${outputDir ?? 'overwrite original'}');
      print("  Input paths: ${results.rest}");
      print("");
    }

    // Regular conversion mode
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
