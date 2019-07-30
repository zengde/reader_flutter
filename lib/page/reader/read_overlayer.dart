import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reader_flutter/bean/volume.dart';
import 'package:reader_flutter/page/reader/reader_config.dart';
import 'package:reader_flutter/util/screen.dart';

import 'battery_view.dart';

class ReaderOverlayer extends StatelessWidget {
  final Chapter chapter;
  final int page;
  final double topSafeHeight;

  ReaderOverlayer({this.chapter, this.page, this.topSafeHeight});

  @override
  Widget build(BuildContext context) {
    var format = DateFormat('HH:mm');
    var time = format.format(DateTime.now());

    return Container(
      padding: EdgeInsets.fromLTRB(
          15, 10 + topSafeHeight, 15, 10 + Screen.bottomSafeHeight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(chapter.name.trim(),
              style: TextStyle(
                  fontSize: ReaderConfig.instance.titleFontSize,
                  color: ReaderConfig.instance.textColor)),
          Expanded(child: Container()),
          Row(
            children: <Widget>[
              BatteryView(),
              SizedBox(width: 10),
              Text(time,
                  style: TextStyle(
                      fontSize: 11, color: ReaderConfig.instance.textColor)),
              Expanded(child: Container()),
              Text('第${page + 1}/${chapter.pageCount}页',
                  style: TextStyle(
                      fontSize: 11, color: ReaderConfig.instance.textColor)),
            ],
          ),
        ],
      ),
    );
  }
}
