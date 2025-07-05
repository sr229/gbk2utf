import "dart:convert";

import "package:gbk2utf/utils.dart";

class GbkEncoder extends Converter<String, List<int>> {
  @override
  List<int> convert(String input) {
    return unicode2gbk(utf82unicode(utf8.encode(input)));
  }
}
