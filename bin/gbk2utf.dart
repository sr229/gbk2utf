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
    ..addFlag(
      "rename-only",
      negatable: false,
      help:
          "Only rename files (decode GBK filenames to UTF-8) without converting content.",
    )
    ..addFlag(
      "skip-filename-correction",
      negatable: false,
      help: "Skip correcting GBK-encoded filenames during conversion.",
    )
    ..addOption(
      "output",
      abbr: "o",
      help: "Output directory (default: overwrite original files).",
    );
}

void printUsage(ArgParser argParser) {
  print("Usage: dart gbk2utf.dart <flags> [files/directories]");
  print("\nConverts GBK encoded files to UTF-8.");
  print("\nOptions:");
  print(argParser.usage);
  print("\nExamples:");
  print(
    "  dart gbk2utf.dart file.txt                    # Convert GBK file to UTF-8 and correct filename",
  );
  print(
    "  dart gbk2utf.dart -b /path/to/directory       # Convert with backup",
  );
  print(
    "  dart gbk2utf.dart -r /path/to/directory       # Recursively convert a directory",
  );
  print(
    "  dart gbk2utf.dart -o /output/dir file1.txt    # Convert to output directory",
  );
  print(
    "  dart gbk2utf.dart --rename-only directory     # Only rename files with GBK-encoded names",
  );
  print(
    "  dart gbk2utf.dart --skip-filename-correction file.txt   # Convert content only, keep original filenames",
  );
  print(
    "  dart utf2gbk.dart file.txt                    # Convert UTF-8 file to GBK (use utf2gbk)",
  );
}

Future<void> convertFileEncoding(
  String filePath, {
  String? outputDir,
  bool verbose = false,
  bool correctFilename = true,
  List<String> inputPaths = const [],
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

    // Convert GBK to UTF-8
    try {
      // Use our GBK codec to decode GBK to string
      final decodedString = gbkCodec.decode(sourceBytes);
      // Then encode as UTF-8
      convertedBytes = utf8.encode(decodedString);
    } catch (e) {
      print("Error converting GBK file $filePath: $e");
      return;
    }

    // Determine output path - this is where filename correction happens
    String outputPath;
    String decodedFileName;

    if (outputDir != null) {
      // Extract just the filename from the full path
      final fileName = basename(filePath);

      // Find the most appropriate base directory from input paths
      String baseDir = _findBaseDir(inputPaths, filePath);

      // Get the subdirectory structure to preserve
      String subDirPath = "";
      if (baseDir.isNotEmpty && filePath.startsWith(baseDir)) {
        // Extract the subdirectory part between baseDir and fileName
        String dirPart = dirname(filePath);
        if (dirPart.length > baseDir.length) {
          subDirPath = dirPart.substring(baseDir.length);
          // Remove any leading separator if present
          if (subDirPath.startsWith(Platform.pathSeparator)) {
            subDirPath = subDirPath.substring(1);
          }
        }
      }

      // Decode the filename if requested (GBK -> UTF-8)
      if (correctFilename) {
        try {
          decodedFileName = gbkCodec.decode(utf8.encode(fileName));
          if (decodedFileName != fileName && verbose) {
            print("Corrected filename: $fileName -> $decodedFileName");
          }
        } catch (e) {
          print("Warning: Failed to decode filename $fileName: $e");
          decodedFileName = fileName;
        }
      } else {
        decodedFileName = fileName;
      }

      // Create output path with preserved directory structure
      if (subDirPath.isNotEmpty) {
        final targetDir = join(outputDir, subDirPath);
        outputPath = join(targetDir, decodedFileName);
      } else {
        outputPath = join(outputDir, decodedFileName);
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
      // When not using output directory, we need to check if we need to rename the file
      if (correctFilename) {
        final fileName = basename(filePath);
        try {
          decodedFileName = gbkCodec.decode(utf8.encode(fileName));

          if (decodedFileName != fileName) {
            // Filename needs correction
            final parent = dirname(filePath);
            outputPath = join(parent, decodedFileName);

            if (verbose) {
              print("Corrected filename: $fileName -> $decodedFileName");
            }
          } else {
            // No correction needed
            outputPath = filePath;
          }
        } catch (e) {
          // If decoding fails, use the original filename
          print("Warning: Failed to decode filename $fileName: $e");
          outputPath = filePath;
        }
      } else {
        // No filename correction
        outputPath = filePath;
      }
    }

    // Write converted content
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(convertedBytes);

    if (verbose) {
      print("Converted (GBK -> UTF-8): $filePath -> $outputPath");
    }
  } catch (e) {
    print("Error processing $filePath: $e");
  }
}

// Helper function to find the base directory for a file
String _findBaseDir(List<String> inputPaths, String filePath) {
  if (inputPaths.isEmpty) return "";

  // Sort input paths by length (descending) so we match the most specific path first
  final sortedPaths = List<String>.from(inputPaths)
    ..sort((a, b) => b.length.compareTo(a.length));

  for (final path in sortedPaths) {
    final dir = Directory(path).existsSync() ? path : dirname(path);
    if (filePath.startsWith(dir)) {
      return dir;
    }
  }

  return "";
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
    final bool renameOnly = results.flag("rename-only");
    final bool skipFilenameCorrection = results.flag(
      "skip-filename-correction",
    );
    final String? outputDir = results.option("output");

    if (verbose) {
      print("Configuration:");
      if (renameOnly) {
        print("  Mode: Rename files only (decode GBK filenames)");
      } else {
        print("  Mode: GBK to UTF-8");
      }
      print("  Verbose: $verbose");
      print("  Backup: $backup");
      print("  Recursive: $recursive");
      print('  Output directory: ${outputDir ?? 'overwrite original'}');
      print("  Correct filenames: ${!skipFilenameCorrection}");
      print("  Input paths: ${results.rest}");
      print("");
    }

    if (renameOnly) {
      // Rename files only mode
      for (final path in results.rest) {
        await processRename(path, recursive: recursive, verbose: verbose);
      }
      print("Renaming completed. Processed ${results.rest.length} paths.");
      return;
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

        // Convert encoding (now with filename correction by default)
        await convertFileEncoding(
          filePath,
          outputDir: outputDir,
          verbose: verbose,
          correctFilename: !skipFilenameCorrection,
          inputPaths: results.rest,
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
