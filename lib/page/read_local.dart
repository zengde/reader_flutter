import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:reader_flutter/bean/book.dart';
import 'package:reader_flutter/bean/mark.dart';
import 'package:reader_flutter/bean/volume.dart';
import 'package:reader_flutter/util/constants.dart';
import 'package:reader_flutter/util/util.dart';
import 'package:reader_flutter/view/load.dart';

import 'catalog_local.dart';

class ReadPageLocal extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    SystemChrome.setEnabledSystemUIOverlays([]);
    return _ReadPageState();
  }

  ReadPageLocal(this.filePath, {this.chapter});

  final String filePath;
  final Chapter chapter;
}

class _ReadPageState extends State<ReadPageLocal>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();

  final BookSqlite _bookSqlite = BookSqlite();

  final BookMarkSqlite _bookMarkSqlite = BookMarkSqlite();

  double _letterSpacing = 2.0;
  double _lineHeight = 2.0;
  double _titleFontSize = 30.0;
  double _contentFontSize = 18.0;
  bool _isShowMenu = false;
  bool _isDayMode = true;
  int _curPosition = 0;
  List<Volume> _volumes = [];
  List<Chapter> _chapters = [];
  Book _book;
  double _progress = 0.0;
  bool _isAdd = false;
  String _content = "";
  bool _isMark = false;

  // 读取 文件 数据，暂时只能utf8格式，gbk库不支持chunk
  // _getChaptersData(start,end) openRead(start,end)
  _getChaptersData() async {
    try {
      String filePath = widget.filePath;
      RegExp volumeExp =
          RegExp(r'^[\s\t　]*(第?[0-9零一二三四五六七八九十]卷|卷[0-9零一二三四五六七八九十]+)\s*.{0,20}$', unicode: true);
      RegExp chpterExp =
          RegExp(r'^[\s\t　]*第?[0-9零一二三四五六七八九十序百千][章节回话]\s*.{0,20}$', unicode: true);

      int k = -1;
      bool iscn = false;
      String _full = '';

      final file = new File('$filePath');
      Stream<List<int>> inputStream = file.openRead();

      Utf8Codec _utf8 = Utf8Codec(allowMalformed: true);
      inputStream
          .transform(_utf8.decoder) // Decode bytes to UTF-8. gbk.decoder
          .transform(new LineSplitter()) // Convert stream to individual lines.
          .listen((String line) {
        if (volumeExp.hasMatch(line)) {
          k++;
          Iterable<RegExpMatch> volumeMatches = volumeExp.allMatches(line);
          _chapters.insert(
              k,
              new Chapter(
                  name: volumeMatches.elementAt(0).group(0),
                  isHeader: true,
                  headerId: k));
          iscn = false;
        } else if (chpterExp.hasMatch(line)) {
          k++;
          Iterable<RegExpMatch> chapterMatches = chpterExp.allMatches(line);
          _chapters.insert(
              k,
              new Chapter(
                  name: chapterMatches.elementAt(0).group(0), isHeader: false));
          iscn = true;
        } else {
          if (iscn) {
            _chapters[k].content = _chapters[k].content + line + "\r\n";
          }
        }
        _full += line + "\r\n";
        // gbk.decode(line)
      }, onDone: () {
        if (_chapters.length < 1) {
          _chapters.insert(0, new Chapter(name: '全文', isHeader: false));
          _chapters[0].content = _full;
        }
        _getChapterData();
        print('File is now closed.');
      }, onError: (e) {
        print(e.toString());
      });
    } catch (err) {
      print(err);
    }
  }

  _getChapterData() {
    setState(() {
      _progress = _curPosition / _chapters.length;
      _content = _chapters[_curPosition].content;
      print("阅读位置$_curPosition");
      print("阅读进度$_progress");
    });
  }

  @override
  void initState() {
    super.initState();
    /*查询是否已添加*/
    _bookSqlite.getBook(0, path: widget.filePath).then((b) {
      if (b != null) {
        _isAdd = true;
        _book = b;
      }
    });
    _getChaptersData();
  }

  @override
  void dispose() {
    _bookSqlite.close();
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
            drawer: new Drawer(
                child: CatalogPageLocal(
                widget.filePath,
                _chapters
                ),
                ),
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
