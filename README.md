# gbk2utf8

This utility is designed to convert any file encoded with GBK to standard UTF-8. This is based on another [package](https://github.com/best-flutter/gbk2utf8) meant for Flutter but has been redone to be usable for non-Flutter applications.

## Usage


### As a command line

To use this utility from the command line, you can run the following commands:

```bash
# Convert a single file
$ gbk2utf file.txt

# Convert with backup and verbose output
$ gbk2utf -b -v file.txt

# Recursively convert all files in a directory
$ gbk2utf -r -b /path/to/directory

# Convert to output directory
$ gbk2utf -o /output/dir file1.txt file2.txt
```

## As a library

You can also use this utility as a library in your Dart or Flutter applications. Here’s how you can do it:

```dart
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
```


## Copyright

Copyright 2025 &copy; Ayase Minori, All Rights Reserved. Licensed under the MIT License. 

Portions of this code is 2018 &copy; Xueliang Ren, Licensed under the MIT License, All Rights Reserved. 