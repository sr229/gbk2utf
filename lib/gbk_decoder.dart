import "dart:convert";

import "package:gbk2utf/utils.dart";

class GbkDecoder extends Converter<List<int>, String> {
  @override
  String convert(List<int> input) {
    return decodeGbk(input);
  }

  String decodeGbk(List<int> codeUnits) {
    return utf8.decode(gbk2utf8(codeUnits));
  }
}
