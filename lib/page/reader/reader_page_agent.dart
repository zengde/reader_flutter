import 'package:flutter/material.dart';
import 'package:reader_flutter/page/reader/reader_config.dart';
import 'package:reader_flutter/page/reader/reader_utils.dart';
import 'package:reader_flutter/util/screen.dart';

class ReaderPageAgent {
  /// 真机慢
  static List<Map<String, int>> getPageOffsets2(
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

  /// 未计算全/半角，英文，数字等
  static List<Map<String, int>> getPageOffsets(
      String content, double topSafeHeight) {
    var height = Screen.height -
        topSafeHeight -
        ReaderUtils.topOffset -
        Screen.bottomSafeHeight -
        ReaderUtils.bottomOffset -
        20;
    var width = Screen.width - 15 - 10;

    List<String> lines = content.split('\n');
    int linesTotal = lines.length;

    List<Map<String, int>> pageConfig = [];

    var size = getTextSize(width);
    // 行高
    double linepixel = size['height'];
    // 每行字数
    int linewords = (width / size['width']).floor();
    // 行数
    int screenlines = (height / linepixel).floor();
    int tmplines = 0;
    int last = 0;
    int tmpoffsets = 0;

    for (var i = 0; i < linesTotal; i++) {
      String line = lines[i];
      var totalline = (line.length / linewords).ceil();
      var offsetline = tmplines + totalline;
      if (offsetline >= screenlines) {
        int totalpage = (offsetline / screenlines).truncate();
        for (int tmppage = 1; tmppage <= totalpage; tmppage++) {
          var end = tmpoffsets + linewords * (tmppage * screenlines - tmplines);
          var offset = {
            'start': last,
            'end': end,
            'screenlines': screenlines,
            'linewords': linewords
          };
          pageConfig.add(offset);
          last = end;
        }
        tmplines = offsetline - screenlines * totalpage;
      } else {
        tmplines += totalline;
      }

      tmpoffsets += line.length + (i < linesTotal - 1 ? 1 : 0);

      if (i == linesTotal - 1 && last < tmpoffsets) {
        pageConfig.add({
          'start': last,
          'end': tmpoffsets,
          'screenlines': screenlines,
          'linewords': linewords
        });
      }
    }
    return pageConfig;
  }

  static Map<String, double> getTextSize(double width) {
    String content = '测\n试';
    TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
        text: content,
        style: TextStyle(
            fontSize: ReaderConfig.instance.contentFontSize,
            letterSpacing: ReaderConfig.instance.letterSpacing,
            height: ReaderConfig.instance.lineHeight));
    textPainter.layout(maxWidth: width);
    var boxs = textPainter.getBoxesForSelection(
        new TextSelection(baseOffset: 0, extentOffset: content.length));
    var start = boxs.first;
    var last = boxs.last;
    return {'width': start.right - start.left, 'height': last.top - start.top};
  }
}
