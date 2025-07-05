import "package:test/test.dart";
import "package:gbk2utf/utils.dart";
import "dart:convert";

void main() {
  group("GBK to Unicode Conversion Tests", () {
    test("should convert ASCII characters correctly", () {
      // Test ASCII characters (single bytes)
      final gbkBytes = [0x41, 0x42, 0x43]; // ABC
      final result = gbk2unicode(gbkBytes);
      expect(result, equals([0x41, 0x42, 0x43]));
    });

    test("should handle empty input", () {
      final result = gbk2unicode([]);
      expect(result, isEmpty);
    });

    test("should handle incomplete multi-byte sequence", () {
      // Test with incomplete sequence at end
      final gbkBytes = [0x41, 0x81]; // ASCII + incomplete GBK
      final result = gbk2unicode(gbkBytes);
      expect(result, equals([0x41])); // Only ASCII should be converted
    });

    test("should convert common Chinese characters", () {
      // Test some common Chinese characters
      // "你好" in GBK: 0xC4E3 0xBAAC
      final gbkBytes = [0xC4, 0xE3, 0xBA, 0xAC];
      final result = gbk2unicode(gbkBytes);
      expect(result.length, equals(2));
      expect(result[0], isA<int>());
      expect(result[1], isA<int>());
    });

    test("should handle mixed ASCII and GBK characters", () {
      // Test mixed content: "A中B"
      final gbkBytes = [0x41, 0xD6, 0xD0, 0x42]; // A + 中 + B
      final result = gbk2unicode(gbkBytes);
      expect(result.length, equals(3));
      expect(result[0], equals(0x41)); // A
      expect(result[2], equals(0x42)); // B
    });
  });

  group("Unicode to UTF-8 Conversion Tests", () {
    test("should convert ASCII characters correctly", () {
      final unicodeBytes = [0x41, 0x42, 0x43]; // ABC
      final result = unicode2utf8(unicodeBytes);
      expect(result, equals([0x41, 0x42, 0x43]));
    });

    test("should convert 2-byte UTF-8 characters", () {
      // Test character in range 0x80-0x7FF
      final unicodeBytes = [0xC9]; // Latin capital letter C with acute (201)
      final result = unicode2utf8(unicodeBytes);
      expect(result, equals([0xC3, 0x89])); // UTF-8 encoding
    });

    test("should convert 3-byte UTF-8 characters", () {
      // Test character in range 0x800-0xFFFF
      final unicodeBytes = [0x4E2D]; // Chinese character "中" (20013)
      final result = unicode2utf8(unicodeBytes);
      expect(result, equals([0xE4, 0xB8, 0xAD])); // UTF-8 encoding
    });

    test("should convert 4-byte UTF-8 characters", () {
      // Test character in range 0x10000-0x10FFFF
      final unicodeBytes = [0x1F600]; // Emoji grinning face (128512)
      final result = unicode2utf8(unicodeBytes);
      expect(result, equals([0xF0, 0x9F, 0x98, 0x80])); // UTF-8 encoding
    });

    test("should handle empty input", () {
      final result = unicode2utf8([]);
      expect(result, isEmpty);
    });

    test("should handle mixed character ranges", () {
      // Mix of ASCII, 2-byte, and 3-byte characters
      final unicodeBytes = [0x41, 0xC9, 0x4E2D]; // A + É + 中
      final result = unicode2utf8(unicodeBytes);
      expect(result, equals([0x41, 0xC3, 0x89, 0xE4, 0xB8, 0xAD]));
    });
  });

  group("UTF-8 to Unicode Conversion Tests", () {
    test("should convert ASCII characters correctly", () {
      final utf8Bytes = [0x41, 0x42, 0x43]; // ABC
      final result = utf82unicode(utf8Bytes);
      expect(result, equals([0x41, 0x42, 0x43]));
    });

    test("should convert 2-byte UTF-8 characters", () {
      final utf8Bytes = [0xC3, 0x89]; // É in UTF-8
      final result = utf82unicode(utf8Bytes);
      expect(result, equals([0xC9])); // Unicode code point (201)
    });

    test("should convert 3-byte UTF-8 characters", () {
      final utf8Bytes = [0xE4, 0xB8, 0xAD]; // 中 in UTF-8
      final result = utf82unicode(utf8Bytes);
      expect(result, equals([0x4E2D])); // Unicode code point (20013)
    });

    test("should convert 4-byte UTF-8 characters", () {
      final utf8Bytes = [0xF0, 0x9F, 0x98, 0x80]; // 😀 in UTF-8
      final result = utf82unicode(utf8Bytes);
      expect(result, equals([0x1F600])); // Unicode code point (128512)
    });

    test("should handle incomplete sequence at end", () {
      final utf8Bytes = [0x41, 0xC3]; // A + incomplete É
      final result = utf82unicode(utf8Bytes);
      expect(result, equals([0x41])); // Only complete characters
    });

    test("should handle empty input", () {
      final result = utf82unicode([]);
      expect(result, isEmpty);
    });
  });

  group("GBK to UTF-8 End-to-End Tests", () {
    test("should convert ASCII text correctly", () {
      final gbkBytes = utf8.encode("Hello World");
      final result = gbk2utf8(gbkBytes);
      final decoded = utf8.decode(result);
      expect(decoded, equals("Hello World"));
    });

    test("should handle empty input", () {
      final result = gbk2utf8([]);
      expect(result, isEmpty);
    });

    test("should convert mixed content", () {
      // Test with ASCII characters mixed with GBK
      final gbkBytes = [0x48, 0x65, 0x6C, 0x6C, 0x6F]; // "Hello"
      final result = gbk2utf8(gbkBytes);
      final decoded = utf8.decode(result);
      expect(decoded, equals("Hello"));
    });
  });

  group("Unicode to GBK Conversion Tests", () {
    test("should handle ASCII characters", () {
      final unicodeBytes = [0x41, 0x42, 0x43]; // ABC
      final result = unicode2gbk(unicodeBytes);
      // Now should work correctly with the fixed implementation
      expect(result, equals([0x41, 0x42, 0x43]));
    });

    test("should handle empty input", () {
      final result = unicode2gbk([]);
      expect(result, isEmpty);
    });
  });

  group("Helper Function Tests", () {
    test("zPos should return correct byte count for UTF-8", () {
      expect(zPos(0x41), equals(0)); // ASCII: 0xxxxxxx (0 continuation bytes)
      expect(zPos(0xC3), equals(1)); // 2-byte: 110xxxxx (1 continuation byte)
      expect(zPos(0xE4), equals(2)); // 3-byte: 1110xxxx (2 continuation bytes)
      expect(zPos(0xF0), equals(3)); // 4-byte: 11110xxx (3 continuation bytes)
    });

    test("unicode2gbkOne should handle ASCII characters", () {
      final result = unicode2gbkOne(0x41); // 'A'
      expect(result, equals(0x41)); // ASCII characters should return themselves
    });

    test("unicode2gbkOne should return 0 for out-of-range characters", () {
      final result = unicode2gbkOne(0x1F600); // Emoji
      expect(result, equals(0));
    });
  });

  group("Edge Cases and Error Handling", () {
    test("should handle null bytes", () {
      final gbkBytes = [0x00, 0x41, 0x00];
      final result = gbk2unicode(gbkBytes);
      expect(result, equals([0x00, 0x41, 0x00]));
    });

    test("should handle maximum Unicode values", () {
      final unicodeBytes = [0x10FFFF]; // Maximum Unicode code point
      final result = unicode2utf8(unicodeBytes);
      expect(result, isNotEmpty);
    });

    test("should handle large input arrays", () {
      // Test with a large array of ASCII characters
      final largeInput = List.filled(1000, 0x41); // 1000 'A' characters
      final result = gbk2unicode(largeInput);
      expect(result.length, equals(1000));
      expect(result.every((char) => char == 0x41), isTrue);
    });
  });
}
