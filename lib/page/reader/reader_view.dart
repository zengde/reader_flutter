import 'package:flutter/material.dart';
import 'package:reader_flutter/bean/volume.dart';
import 'package:reader_flutter/page/reader/read_overlayer.dart';
import 'package:reader_flutter/page/reader/reader_config.dart';
import 'package:reader_flutter/page/reader/reader_utils.dart';
import 'package:reader_flutter/util/screen.dart';

class ReaderView extends StatelessWidget {
  final Chapter chapter;
  final int page;
  final double topSafeHeight;

  ReaderView({this.chapter, this.page, this.topSafeHeight});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        ReaderOverlayer(
            chapter: chapter, page: page, topSafeHeight: topSafeHeight),
        buildContent(chapter, page),
      ],
    );
  }

  buildContent(Chapter chapter, int page) {
    var content = chapter.stringAtPageIndex(page);

    return Container(
      color: Colors.transparent,
      margin: EdgeInsets.fromLTRB(15, topSafeHeight + ReaderUtils.topOffset, 10,
          Screen.bottomSafeHeight + ReaderUtils.bottomOffset),
      child: Text(
        content,
        style: TextStyle(
          color: ReaderConfig.instance.textColor,
          height: ReaderConfig.instance.lineHeight,
          fontSize: ReaderConfig.instance.contentFontSize,
          letterSpacing: ReaderConfig.instance.letterSpacing,
        ),
      ),
    );
  }
}
