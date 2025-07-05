import "dart:convert";

import "package:gbk2utf/gbk_decoder.dart";
import "package:gbk2utf/gbk_encoder.dart";


class GbkCodec extends Encoding {
  @override
  Converter<List<int>, String> get decoder => GbkDecoder();

  @override
  Converter<String, List<int>> get encoder => GbkEncoder();

  @override
  String get name => "gbk";
}