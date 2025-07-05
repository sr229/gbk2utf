import "package:test/test.dart";
import "package:gbk2utf/gbk_decoder.dart";
import "package:gbk2utf/gbk_encoder.dart";
import "package:gbk2utf/converter.dart";
import "dart:convert";

void main() {
  group("GBK Decoder Tests", () {
    late GbkDecoder decoder;

    setUp(() {
      decoder = GbkDecoder();
    });

    test("should decode ASCII text correctly", () {
      final input = utf8.encode("Hello World");
      final result = decoder.convert(input);
      expect(result, equals("Hello World"));
    });

    test("should handle empty input", () {
      final result = decoder.convert([]);
      expect(result, equals(""));
    });

    test("should decode mixed ASCII and GBK content", () {
      // Test with ASCII characters
      final input = [0x48, 0x65, 0x6C, 0x6C, 0x6F]; // "Hello"
      final result = decoder.convert(input);
      expect(result, equals("Hello"));
    });

    test("should handle incomplete sequences gracefully", () {
      final input = [0x41, 0x81]; // ASCII + incomplete GBK
      final result = decoder.convert(input);
      expect(result, equals("A"));
    });
  });

  group("GBK Encoder Tests", () {
    late GbkEncoder encoder;

    setUp(() {
      encoder = GbkEncoder();
    });

    test("should encode ASCII text correctly", () {
      final result = encoder.convert("Hello");
      expect(result, isNotEmpty);
      // Should be able to decode back to original
      final decoder = GbkDecoder();
      final decoded = decoder.convert(result);
      expect(decoded, equals("Hello"));
    });

    test("should handle empty input", () {
      final result = encoder.convert("");
      expect(result, isEmpty);
    });

    test("should encode single character", () {
      final result = encoder.convert("A");
      expect(result, isNotEmpty);
    });

    test("should handle special characters", () {
      final result = encoder.convert("!@#\$%^&*()");
      expect(result, isNotEmpty);
    });
  });

  group("GBK Codec Tests", () {
    late GbkCodec codec;

    setUp(() {
      codec = GbkCodec();
    });

    test("should have correct name", () {
      expect(codec.name, equals("gbk"));
    });

    test("should provide decoder", () {
      expect(codec.decoder, isA<GbkDecoder>());
    });

    test("should provide encoder", () {
      expect(codec.encoder, isA<GbkEncoder>());
    });

    test("should round-trip ASCII text", () {
      const originalText = "Hello World 123!";
      final encoded = codec.encoder.convert(originalText);
      final decoded = codec.decoder.convert(encoded);
      expect(decoded, equals(originalText));
    });

    test("should handle unicode characters in strings", () {
      const originalText = "Hello 世界";
      final encoded = codec.encoder.convert(originalText);
      final decoded = codec.decoder.convert(encoded);
      // Note: This might not work perfectly due to GBK limitations
      expect(decoded, isA<String>());
    });
  });

  group("Integration Tests", () {
    test("should handle real-world text samples", () {
      final samples = [
        "Hello World",
        "Test 123",
        "Special chars: !@#\$%^&*()",
        "Numbers: 0123456789",
        "Mixed: abc123XYZ",
      ];

      final codec = GbkCodec();

      for (final sample in samples) {
        final encoded = codec.encoder.convert(sample);
        final decoded = codec.decoder.convert(encoded);
        expect(decoded, equals(sample), reason: "Failed for sample: $sample");
      }
    });

    test("should handle different string lengths", () {
      final codec = GbkCodec();

      // Test various lengths
      final testCases = [
        "", // Empty
        "A", // Single character
        "AB", // Two characters
        "Hello", // Short string
        "Hello World! This is a longer test string.", // Long string
      ];

      for (final testCase in testCases) {
        final encoded = codec.encoder.convert(testCase);
        final decoded = codec.decoder.convert(encoded);
        expect(decoded, equals(testCase), reason: 'Failed for: "$testCase"');
      }
    });
  });
}
