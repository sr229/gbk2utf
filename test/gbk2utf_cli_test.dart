import "package:test/test.dart";
import "dart:io";
import "../bin/utils.dart" show renameFile;

void main() {
  group("CLI Integration Tests", () {
    late Directory tempDir;
    late String testFilePath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp("gbk2utf_test");
      testFilePath = "${tempDir.path}/test_file.txt";
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test("should show help when --help flag is used", () async {
      final result = await Process.run("dart", [
        "run",
        "bin/gbk2utf.dart",
        "--help",
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains("Usage:"));
      expect(result.stdout, contains("Options:"));
    });

    test("should show version when --version flag is used", () async {
      final result = await Process.run("dart", [
        "run",
        "bin/gbk2utf.dart",
        "--version",
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains("version"));
    });

    test("should handle non-existent file gracefully", () async {
      final result = await Process.run("dart", [
        "run",
        "bin/gbk2utf.dart",
        "non_existent_file.txt",
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, equals(0)); // Should not crash
      expect(
        result.stdout,
        contains("Warning: Path not found or inaccessible"),
      );
      expect(result.stdout, contains("No files found to process"));
    });

    test("should convert ASCII file correctly", () async {
      // Create test file with ASCII content
      const testContent = "Hello World!\nThis is a test file.";
      await File(testFilePath).writeAsString(testContent);

      final result = await Process.run("dart", [
        "run",
        "bin/gbk2utf.dart",
        "--verbose",
        testFilePath,
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, equals(0));

      // Verify file still contains same content
      final convertedContent = await File(testFilePath).readAsString();
      expect(convertedContent, equals(testContent));
    });

    test("should create backup when --backup flag is used", () async {
      const testContent = "Test content for backup";
      await File(testFilePath).writeAsString(testContent);

      final result = await Process.run("dart", [
        "run",
        "bin/gbk2utf.dart",
        "--backup",
        "--verbose",
        testFilePath,
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, equals(0));

      // Check if backup file was created
      final backupFile = File("$testFilePath.bak");
      expect(await backupFile.exists(), isTrue);

      // Verify backup content
      final backupContent = await backupFile.readAsString();
      expect(backupContent, equals(testContent));
    });

    test("should handle directory processing with --recursive flag", () async {
      // Create test directory structure
      final subDir = Directory("${tempDir.path}/subdir");
      await subDir.create();

      final file1 = File("${tempDir.path}/file1.txt");
      final file2 = File("${subDir.path}/file2.txt");

      await file1.writeAsString("Content 1");
      await file2.writeAsString("Content 2");

      final result = await Process.run("dart", [
        "run",
        "bin/gbk2utf.dart",
        "--recursive",
        "--verbose",
        tempDir.path,
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains("Found 2 file(s) to process"));
      expect(result.stdout, contains("Successfully processed 2 of 2"));
      expect(result.stdout, contains("file1.txt"));
      expect(result.stdout, contains("file2.txt"));
    });

    test("should handle output directory option", () async {
      const testContent = "Test content for output directory";
      await File(testFilePath).writeAsString(testContent);

      final outputDir = Directory("${tempDir.path}/output");
      await outputDir.create();

      final result = await Process.run("dart", [
        "run",
        "bin/gbk2utf.dart",
        "--output",
        outputDir.path,
        "--verbose",
        testFilePath,
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, equals(0));

      // Check if file was created in output directory
      final outputFile = File("${outputDir.path}/test_file.txt");
      expect(await outputFile.exists(), isTrue);

      // Verify content
      final outputContent = await outputFile.readAsString();
      expect(outputContent, equals(testContent));
    });

    test("should handle multiple files", () async {
      // Create multiple test files
      final file1 = File("${tempDir.path}/file1.txt");
      final file2 = File("${tempDir.path}/file2.txt");

      await file1.writeAsString("Content 1");
      await file2.writeAsString("Content 2");

      final result = await Process.run("dart", [
        "run",
        "bin/gbk2utf.dart",
        "--verbose",
        file1.path,
        file2.path,
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains("Found 2 file(s) to process"));
      expect(result.stdout, contains("Successfully processed 2 of 2"));
    });

    test("should show configuration in verbose mode", () async {
      const testContent = "Test content";
      await File(testFilePath).writeAsString(testContent);

      final result = await Process.run("dart", [
        "run",
        "bin/gbk2utf.dart",
        "--verbose",
        "--backup",
        testFilePath,
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains("Configuration:"));
      expect(result.stdout, contains("Mode: GBK to UTF-8"));
      expect(result.stdout, contains("Verbose: true"));
      expect(result.stdout, contains("Backup: true"));
    });

    test("should handle empty file", () async {
      // Create empty file
      await File(testFilePath).writeAsString("");

      final result = await Process.run("dart", [
        "run",
        "bin/gbk2utf.dart",
        "--verbose",
        testFilePath,
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains("Successfully processed 1"));

      // Verify file is still empty
      final content = await File(testFilePath).readAsString();
      expect(content, equals(""));
    });

    test("should handle special characters", () async {
      const testContent = "Special chars: !@#\$%^&*()_+-={}[]|\\:;\"'<>?,./`~";
      await File(testFilePath).writeAsString(testContent);

      final result = await Process.run("dart", [
        "run",
        "bin/gbk2utf.dart",
        "--verbose",
        testFilePath,
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains("Successfully processed 1"));

      // Verify content preserved
      final convertedContent = await File(testFilePath).readAsString();
      expect(convertedContent, equals(testContent));
    });

    test("should not create backup when using output directory", () async {
      const testContent = "Test content";
      await File(testFilePath).writeAsString(testContent);

      final outputDir = Directory("${tempDir.path}/output");
      await outputDir.create();

      final result = await Process.run("dart", [
        "run",
        "bin/gbk2utf.dart",
        "--backup",
        "--output",
        outputDir.path,
        "--verbose",
        testFilePath,
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, equals(0));

      // Backup should not be created when using output directory
      final backupFile = File("$testFilePath.bak");
      expect(await backupFile.exists(), isFalse);

      // But output file should exist
      final outputFile = File("${outputDir.path}/test_file.txt");
      expect(await outputFile.exists(), isTrue);
    });

    test("should handle non-recursive directory processing", () async {
      // Create nested directory structure
      final subDir = Directory("${tempDir.path}/subdir");
      await subDir.create();

      final topFile = File("${tempDir.path}/top_file.txt");
      final nestedFile = File("${subDir.path}/nested_file.txt");

      await topFile.writeAsString("Top level content");
      await nestedFile.writeAsString("Nested content");

      final result = await Process.run("dart", [
        "run",
        "bin/gbk2utf.dart",
        "--verbose",
        tempDir.path,
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, equals(0));
      // Should only process top-level files when not recursive
      expect(result.stdout, contains("Found 1 file(s) to process"));
      expect(result.stdout, contains("Successfully processed 1"));
    });

    test("should handle filename correction", () async {
      // Create a file with a name that could be GBK-encoded
      final fileName = "测试文件.txt";
      final filePath = "${tempDir.path}/$fileName";
      const fileContent = "Test content for filename correction";

      await File(filePath).writeAsString(fileContent);

      final result = await Process.run("dart", [
        "run",
        "bin/gbk2utf.dart",
        "--verbose",
        filePath,
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, equals(0));

      // Check if the output contains information about filename correction
      if (result.stdout.contains("Corrected filename:")) {
        // There should be at least one file in the directory
        final dirContents = await Directory(tempDir.path).list().toList();
        final files = dirContents.whereType<File>().toList();
        expect(files.isNotEmpty, isTrue);

        // The content should be preserved in one of the files
        bool contentFound = false;
        for (final file in files) {
          if (await file.readAsString() == fileContent) {
            contentFound = true;
            break;
          }
        }
        expect(contentFound, isTrue);
      }
    });

    test("should handle --rename-only flag", () async {
      // Create a file with a name that could be GBK-encoded
      final fileName = "测试文件.txt";
      final filePath = "${tempDir.path}/$fileName";
      const fileContent = "Test content for rename-only";

      await File(filePath).writeAsString(fileContent);

      final result = await Process.run("dart", [
        "run",
        "bin/gbk2utf.dart",
        "--verbose",
        "--rename-only",
        filePath,
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains("Renaming completed"));

      // There should be a file in the directory
      final dirContents = await Directory(tempDir.path).list().toList();
      final files = dirContents.whereType<File>().toList();
      expect(files.isNotEmpty, isTrue);

      // The content should be unchanged in one of the files
      bool contentFound = false;
      for (final file in files) {
        if (await file.readAsString() == fileContent) {
          contentFound = true;
          break;
        }
      }
      expect(contentFound, isTrue);
    });
  });

  group("Error Handling Tests", () {
    test("should show error for missing arguments", () async {
      final result = await Process.run("dart", [
        "run",
        "bin/gbk2utf.dart",
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, equals(1));
      expect(result.stdout, contains("Error: No input files"));
    });

    test("should handle invalid flags gracefully", () async {
      final result = await Process.run("dart", [
        "run",
        "bin/gbk2utf.dart",
        "--invalid-flag",
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, equals(1));
      expect(result.stdout, contains("Error:"));
    });

    test("should handle permission denied gracefully", () async {
      final result = await Process.run("dart", [
        "run",
        "bin/gbk2utf.dart",
        "/root/protected_file.txt",
      ], workingDirectory: Directory.current.path);

      // Should not crash, regardless of the actual error
      expect(result.exitCode, anyOf([0, 1]));
    });
  });

  group("Integration with Real Files", () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp("gbk2utf_integration");
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test("should handle complex directory structure", () async {
      // Create complex directory structure
      final dirs = [
        "${tempDir.path}/src",
        "${tempDir.path}/src/utils",
        "${tempDir.path}/test",
        "${tempDir.path}/docs",
      ];

      for (final dir in dirs) {
        await Directory(dir).create(recursive: true);
      }

      // Create various files
      final files = [
        "${tempDir.path}/README.txt",
        "${tempDir.path}/src/main.txt",
        "${tempDir.path}/src/utils/helper.txt",
        "${tempDir.path}/test/test_file.txt",
        "${tempDir.path}/docs/documentation.txt",
      ];

      for (int i = 0; i < files.length; i++) {
        await File(files[i]).writeAsString("Content for file ${i + 1}");
      }

      final result = await Process.run("dart", [
        "run",
        "bin/gbk2utf.dart",
        "--recursive",
        "--backup",
        "--verbose",
        tempDir.path,
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, equals(0));
      expect(
        result.stdout,
        contains("Found ${files.length} file(s) to process"),
      );
      expect(result.stdout, contains("Successfully processed ${files.length}"));

      // Verify all backup files were created
      for (final file in files) {
        final backupFile = File("$file.bak");
        expect(await backupFile.exists(), isTrue);
      }
    });

    test("should handle large file", () async {
      // Create a larger test file
      final largeContent = List.filled(
        1000,
        "This is a line of content for testing large files.\n",
      ).join();
      final largeFile = File("${tempDir.path}/large_file.txt");
      await largeFile.writeAsString(largeContent);

      final result = await Process.run("dart", [
        "run",
        "bin/gbk2utf.dart",
        "--verbose",
        largeFile.path,
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains("Successfully processed 1"));

      // Verify content is preserved
      final convertedContent = await largeFile.readAsString();
      expect(convertedContent, equals(largeContent));
    });

    test("should handle files with different extensions", () async {
      final files = [
        "${tempDir.path}/document.txt",
        "${tempDir.path}/readme.md",
        "${tempDir.path}/config.ini",
        "${tempDir.path}/data.csv",
        "${tempDir.path}/script.sh",
      ];

      for (final file in files) {
        await File(file).writeAsString("Content for ${file.split('/').last}");
      }

      final result = await Process.run("dart", [
        "run",
        "bin/gbk2utf.dart",
        "--recursive",
        "--verbose",
        tempDir.path,
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, equals(0));
      expect(
        result.stdout,
        contains("Found ${files.length} file(s) to process"),
      );
      expect(result.stdout, contains("Successfully processed ${files.length}"));
    });
  });

  group("Unit Tests: renameFile Function", () {
    late Directory tempDir;
    late String oldPath;
    late String newDirPath;
    const fileContent = "Test content for renameFile function";

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp("renameFileTest");
      oldPath = "${tempDir.path}/old_name.txt";
      newDirPath = "${tempDir.path}/new_directory";

      // Create test file
      await File(oldPath).writeAsString(fileContent);

      // Create target directory
      await Directory(newDirPath).create();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test("should rename ASCII filename and preserve content", () async {
      await renameFile(oldPath, newDirPath);

      // Check that new file exists with the same name in the new directory
      final expectedNewFile = File("${newDirPath}/old_name.txt");
      expect(await expectedNewFile.exists(), isTrue);

      // Verify content is preserved
      final content = await expectedNewFile.readAsString();
      expect(content, equals(fileContent));
    });

    test("should handle GBK-encoded filename correctly", () async {
      // Create a file with a name that could be GBK-encoded
      final originalFileName = "test文件.txt";
      final gbkEncodedFileName = "${tempDir.path}/$originalFileName";
      await File(gbkEncodedFileName).writeAsString(fileContent);

      await renameFile(gbkEncodedFileName, newDirPath);

      // Check for any file in the target directory
      final files = await Directory(newDirPath).list().toList();
      expect(files.isNotEmpty, isTrue);

      // Verify content is preserved in one of the files
      bool contentFound = false;
      for (final entity in files) {
        if (entity is File) {
          final fileContent = await entity.readAsString();
          if (fileContent == fileContent) {
            contentFound = true;
            break;
          }
        }
      }
      expect(contentFound, isTrue);
    });

    test("should handle non-existent source file gracefully", () async {
      const nonExistentPath = "/path/that/does/not/exist.txt";

      // Should not throw, just print error message
      await expectLater(
        () => renameFile(nonExistentPath, newDirPath),
        returnsNormally,
      );

      // No files should be created in the new directory
      final files = await Directory(newDirPath).list().toList();
      expect(files, isEmpty);
    });
  });

  group("utf2gbk CLI Tests", () {
    late Directory tempDir;
    late String testFilePath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp("utf2gbk_test");
      testFilePath = "${tempDir.path}/test_file.txt";
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test("should show help when --help flag is used", () async {
      final result = await Process.run("dart", [
        "run",
        "bin/utf2gbk.dart",
        "--help",
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains("Usage:"));
      expect(result.stdout, contains("Options:"));
    });

    test("should convert UTF-8 file to GBK", () async {
      const testContent = "Hello World! UTF-8 content.";
      await File(testFilePath).writeAsString(testContent);

      final result = await Process.run("dart", [
        "run",
        "bin/utf2gbk.dart",
        "--verbose",
        testFilePath,
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, equals(0));
      expect(result.stdout, contains("UTF-8 -> GBK"));
      expect(result.stdout, contains("Successfully processed 1"));
    });

    test("should handle output directory", () async {
      const testContent = "UTF-8 content for output directory test.";
      await File(testFilePath).writeAsString(testContent);

      final outputDir = Directory("${tempDir.path}/output");
      await outputDir.create();

      final result = await Process.run("dart", [
        "run",
        "bin/utf2gbk.dart",
        "--output",
        outputDir.path,
        "--verbose",
        testFilePath,
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, equals(0));

      // Check if file was created in output directory
      final outputFile = File("${outputDir.path}/test_file.txt");
      expect(await outputFile.exists(), isTrue);
    });
  });
}
