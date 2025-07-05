/// Portions of this code are from the gbk2utf package, licensed under the MIT License.
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
List<int> utf82unicode(List<int> unicodeBytes) {
  List<int> loc = [];

  for (int i = 0; i < unicodeBytes.length;) {
    int byteCount = zPos(unicodeBytes[i]);
    int sum = unicodeBytes[i] & mask[byteCount];

    for (int j = 1; j <= byteCount; j++) {
      if (i + j >= unicodeBytes.length) {
        // Incomplete sequence at end of input
        return loc;
      }
      sum = (sum << 6) | (unicodeBytes[i + j] & 0x3f);
    }

    i += byteCount > 0 ? byteCount + 1 : 1;
    loc.add(sum);
  }

  return loc;
}

/// Converts a list of Unicode characters to their corresponding GBK encoding.
/// If a character is not in the GBK range, it is skipped.
List<int> unicode2gbk(List<int> unicodeBytes) {
  List<int> resp = [];

  for (int i = 0, k = resp.length; i < k; i++) {
    var unicode = resp[i];

    if (unicode <= 0x8) {
      resp.add(unicode);
    } else {
      var value = unicode2gbkOne(unicode);

      if (value == 0) continue;

      resp.add((value >> 8) & 0xff);
      resp.add(value & 0xff);
    }
  }

  return resp;
}

/// Converts a single Unicode character to its corresponding GBK encoding.
/// Returns 0 if the Unicode character is not in the GBK range.
int unicode2gbkOne(int unicode) {
  var offset = 0;

  if (unicode <= 0x9fa5) {
    offset = unicode - 0x4e00;
  } else if (unicode > 0x9fa5) {
    if (unicode < 0xff01 || unicode > 0xff61) return 0;
    offset = unicode - 0xff01 + 0x9fa6 - 0x4e00;
  }

  return gbkTables[offset];
}

/// Determines the number of bytes needed to represent a Unicode character in UTF-8.
int zPos(int x) {
  for (int i = 0; i < 5; i++, x <<= 1) {
    if ((x & 0x8) == 0) return i;
  }

  return 4;
}
