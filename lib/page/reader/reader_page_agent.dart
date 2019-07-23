import 'package:flutter/material.dart';
import 'package:reader_flutter/page/reader/reader_config.dart';
import 'package:reader_flutter/page/reader/reader_utils.dart';
import 'package:reader_flutter/util/screen.dart';

class ReaderPageAgent {
  static List<Map<String, int>> getPageOffsets(
      String content, double topSafeHeight) {
    var height = Screen.height -
        topSafeHeight -
        ReaderUtils.topOffset -
        Screen.bottomSafeHeight -
        ReaderUtils.bottomOffset -
        20;
    var width = Screen.width - 15 - 10;

    String tempStr = content;
    List<Map<String, int>> pageConfig = [];
    int last = 0;
    while (true) {
      Map<String, int> offset = {};
      offset['start'] = last;
      TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
      textPainter.text = TextSpan(
          text: tempStr,
          style: TextStyle(
              fontSize: ReaderConfig.instance.contentFontSize,
              letterSpacing: ReaderConfig.instance.letterSpacing,
              height: ReaderConfig.instance.lineHeight));
      textPainter.layout(maxWidth: width);
      var end = textPainter.getPositionForOffset(Offset(width, height)).offset;

      if (end == 0) {
        break;
      }
      tempStr = tempStr.substring(end, tempStr.length);
      offset['end'] = last + end;
      last = last + end;
      pageConfig.add(offset);
    }
    return pageConfig;
  }
}
