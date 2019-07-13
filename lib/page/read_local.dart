import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:reader_flutter/util/constants.dart';
import 'package:reader_flutter/view/load.dart';

class ReadPageLocal extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    SystemChrome.setEnabledSystemUIOverlays([]);
    return _ReadPageState();
  }

  ReadPageLocal(this.filePath);

  final String filePath;
}

class _ReadPageState extends State<ReadPageLocal>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();

  String _content = '';
  double _letterSpacing = 2.0;
  double _lineHeight = 2.0;
  double _titleFontSize = 30.0;
  double _contentFontSize = 18.0;
  bool _isShowMenu = false;
  bool _isDayMode = true;

  // 读取 文件 数据，暂时只能utf8格式，gbk库不支持chunk
  // readFile(start,end) openRead(start,end)
  void readFile() async {
    try {
      String filePath = widget.filePath;
      final file = new File('$filePath');
      Stream<List<int>> inputStream = file.openRead();
      String str = '';
      Utf8Codec _utf8 = Utf8Codec(allowMalformed: true);
      inputStream
          .transform(_utf8.decoder) // Decode bytes to UTF-8. gbk.decoder
          .transform(new LineSplitter()) // Convert stream to individual lines.
          .listen((String line) {
        str += line+"\r\n";
		// todo 匹配章节
		// gbk.decode(line)
      }, onDone: () {
        setState(() {
          _content = str;
        });
        print('File is now closed.');
      }, onError: (e) {
        print(e.toString());
      });
    } catch (err) {
      print(err);
    }
  }

  @override
  void initState() {
    super.initState();
    readFile();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIOverlays(
        [SystemUiOverlay.top, SystemUiOverlay.bottom]);
    super.dispose();
  }

  Widget _contentView() {
    return Container(
      child: Text(
        _content,
        style: TextStyle(
          color: _isDayMode
              ? AppColors.DayModeTextColor
              : AppColors.NightModeTextColor,
          height: _lineHeight,
          fontSize: _contentFontSize,
          letterSpacing: _letterSpacing,
        ),
      ),
    );
  }

  Widget _titleView() {
    return Text(
      widget.filePath,
      style: TextStyle(
        color: _isDayMode
            ? AppColors.DayModeTextColor
            : AppColors.NightModeTextColor,
        fontSize: _titleFontSize,
        letterSpacing: 2,
      ),
    );
  }

  Widget reader() {
    return Container(
      color: _isDayMode ? AppColors.DayModeBgColor : AppColors.NightModeBgColor,
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,
      child: Stack(
        children: <Widget>[
          SingleChildScrollView(
            controller: _scrollController,
            child: Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: kToolbarHeight,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _titleView(),
                  _contentView(),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _topMenu() {
    return Container(
      height: kToolbarHeight + MediaQuery.of(context).padding.top,
      width: MediaQuery.of(context).size.width,
      child: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        iconTheme: IconThemeData(color: AppColors.DayModeIconTitleButtonColor),
        backgroundColor: AppColors.DayModeMenuBgColor,
      ),
    );
  }

  Widget _bottomMenu() {
    return Container(
        width: MediaQuery.of(context).size.width,
        color: AppColors.DayModeMenuBgColor);
  }

  @override
  Widget build(BuildContext context) {
    return _content == ''
        ? LoadingPage()
        : Scaffold(
            drawer: new Drawer(),
            body: Stack(
              children: <Widget>[
                reader(),
                _isShowMenu
                    ? Positioned(
                        child: _topMenu(),
                        top: 0,
                      )
                    : Container(),
                _isShowMenu
                    ? Positioned(
                        child: _bottomMenu(),
                        bottom: 0,
                      )
                    : Container(),
              ],
            ),
          );
  }

  @override
  bool get wantKeepAlive => true;
}
