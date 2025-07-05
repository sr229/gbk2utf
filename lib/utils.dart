/// Portions of this code are from the gbk2utf8 package, licensed under the MIT License.
/// Copyright (c) 2018 Xueliang Ren
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in all
/// copies or substantial portions of the Software.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
/// SOFTWARE.
library;

import "package:gbk2utf/gbk_table.dart";
import "package:gbk2utf/unicode_table.dart";

List<int> mask = [0x7f, 0x3f, 0x1f, 0x0f, 0x7];

/// Converts a list of GBK encoded bytes to their corresponding UTF-8 encoded bytes.
List<int> gbk2utf8(List<int> gbkBytes) {
  return unicode2utf8(gbk2unicode(gbkBytes));
}

/// Converts a list of GBK encoded bytes to their corresponding Unicode characters.
List<int> gbk2unicode(List<int> gbkBytes) {
  int uniInd = 0, gbkInd = 0;
  List<int> uniPtr = List.filled(gbkBytes.length, 0);

  while (gbkInd < gbkBytes.length) {
    int ch = gbkBytes[gbkInd];

    // ASCII characters (0x00-0x7F) are single bytes
    if (ch < 0x80) {
      uniPtr[uniInd] = ch;
      uniInd++;
      gbkInd++;
    } else {
      // GBK multi-byte character - need two bytes
      if (gbkInd + 1 >= gbkBytes.length) {
        // Incomplete multi-byte sequence at end of input
        break;
      }

      int word = (ch << 8) | gbkBytes[gbkInd + 1];
      int wordPos = word - gbkFirstCode;

      if (word >= gbkFirstCode &&
          word <= gbkLastCode &&
          wordPos < unicodeBufferSize) {
        uniPtr[uniInd] = unicodeTables[wordPos];
        uniInd++;
      }
      gbkInd += 2;
    }
  }

  // Return properly resized list
  return uniPtr.take(uniInd).toList();
}

/// Converts a list of Unicode characters to their corresponding UTF-8 encoded bytes.
List<int> unicode2utf8(List<int> unicodeBytes) {
  List<int> utf8Bytes = [];

  for (int unicode in unicodeBytes) {
    if (unicode < 0x80) {
      // Single byte for ASCII characters
      utf8Bytes.add(unicode);
    } else if (unicode < 0x800) {
      // Two bytes for characters in the range 0x80-0x7FF
      utf8Bytes.add(0xc0 | (unicode >> 6));
      utf8Bytes.add(0x80 | (unicode & 0x3f));
    } else if (unicode < 0x10000) {
      // Three bytes for characters in the range 0x800-0xFFFF
      utf8Bytes.add(0xe0 | (unicode >> 12));
      utf8Bytes.add(0x80 | ((unicode >> 6) & 0x3f));
      utf8Bytes.add(0x80 | (unicode & 0x3f));
    } else {
      // Four bytes for characters in the range 0x10000-0x10FFFF
      utf8Bytes.add(0xf0 | (unicode >> 18));
      utf8Bytes.add(0x80 | ((unicode >> 12) & 0x3f));
      utf8Bytes.add(0x80 | ((unicode >> 6) & 0x3f));
      utf8Bytes.add(0x80 | (unicode & 0x3f));
    }
  }

  return utf8Bytes;
}

/// Converts a list of UTF-8 encoded bytes to their corresponding Unicode characters.
List<int> utf82unicode(List<int> utf8Bytes) {
  List<int> loc = [];

  for (int i = 0; i < utf8Bytes.length;) {
    int firstByte = utf8Bytes[i];
    int byteCount = zPos(firstByte);
    int unicode;

    if (byteCount == 0) {
      // Single byte (ASCII)
      unicode = firstByte;
      i++;
    } else {
      // Multi-byte sequence
      if (i + byteCount >= utf8Bytes.length) {
        // Incomplete sequence at end of input
        break;
      }

      // Extract the significant bits from the first byte
      unicode = firstByte & mask[byteCount];

      // Process continuation bytes
      for (int j = 1; j <= byteCount; j++) {
        if (i + j >= utf8Bytes.length) {
          // Incomplete sequence
          return loc;
        }
        unicode = (unicode << 6) | (utf8Bytes[i + j] & 0x3f);
      }

      i += byteCount + 1;
    }

    loc.add(unicode);
  }

  return loc;
}

/// Determines the number of bytes needed to represent a Unicode character in UTF-8.
/// Returns the number of continuation bytes (so total bytes = return value + 1)
int zPos(int x) {
  if ((x & 0x80) == 0) return 0; // 0xxxxxxx = ASCII (0 continuation bytes)
  if ((x & 0xE0) == 0xC0) return 1; // 110xxxxx = 2-byte (1 continuation byte)
  if ((x & 0xF0) == 0xE0) return 2; // 1110xxxx = 3-byte (2 continuation bytes)
  if ((x & 0xF8) == 0xF0) return 3; // 11110xxx = 4-byte (3 continuation bytes)
  return 4; // Invalid or unsupported
}

/// Converts a single Unicode character to its corresponding GBK encoding.
/// Returns 0 if the Unicode character is not in the GBK range.
int unicode2gbkOne(int unicode) {
  // Handle ASCII characters directly
  if (unicode < 0x80) {
    return unicode;
  }

  var offset = 0;

  if (unicode >= 0x4e00 && unicode <= 0x9fa5) {
    // CJK Unified Ideographs range
    offset = unicode - 0x4e00;
  } else if (unicode >= 0xff01 && unicode <= 0xff61) {
    // Fullwidth Forms range
    offset = unicode - 0xff01 + 0x9fa6 - 0x4e00;
  } else {
    // Character not in GBK range
    return 0;
  }

  // Check bounds before accessing the array
  if (offset < 0 || offset >= gbkTables.length) {
    return 0;
  }

  return gbkTables[offset];
}

/// Converts a list of Unicode characters to their corresponding GBK encoding.
/// If a character is not in the GBK range, it is skipped.
List<int> unicode2gbk(List<int> unicodeBytes) {
  List<int> resp = [];

  // Fix the loop - use unicodeBytes.length instead of resp.length
  for (int i = 0; i < unicodeBytes.length; i++) {
    var unicode = unicodeBytes[i];

    if (unicode <= 0x7F) {
      // ASCII characters
      resp.add(unicode);
    } else {
      var value = unicode2gbkOne(unicode);

      if (value == 0) continue;

      // Add high byte and low byte
      resp.add((value >> 8) & 0xff);
      resp.add(value & 0xff);
    }
  }

  return resp;
}
