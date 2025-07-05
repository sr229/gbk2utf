import "package:gbk2utf/converter.dart";

void main() {
  GbkCodec codec = GbkCodec();

  // Example usage of the GbkCodec
  final inputString = "Hello, 世界!";
  final encodedBytes = codec.encode(inputString);
  print(encodedBytes);

  // Decode example
  final decodedString = codec.decode(encodedBytes);

  // Verify that the decoded string matches the original input
  if (decodedString == inputString) {
    print("Encoding and decoding successful!");
  } else {
    print("Mismatch: $decodedString != $inputString");
  }
}
