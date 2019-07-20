import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:intl/intl.dart';
import 'package:reader_flutter/bean/book.dart';
import 'package:reader_flutter/bean/mark.dart';
import 'package:reader_flutter/bean/volume.dart';
import 'package:reader_flutter/page/reader/battery_view.dart';
import 'package:reader_flutter/page/reader/reader_page_agent.dart';
import 'package:reader_flutter/util/constants.dart';
import 'package:reader_flutter/util/screen.dart';
import 'package:reader_flutter/util/util.dart';
import 'package:reader_flutter/view/load.dart';

import 'catalog_local.dart';
import 'reader/reader_utils.dart';

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
  final BookSqlite _bookSqlite = BookSqlite();

  final BookMarkSqlite _bookMarkSqlite = BookMarkSqlite();

  double _letterSpacing = 2.0;
  double _lineHeight = 1.5;
  double _titleFontSize = 14.0;
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
  int _curPage;
  List<Map<String, int>> _pageOffsets;
  double topSafeHeight = 0;
  PageController pageController = PageController(keepPage: false);

  // _getChaptersData(start,end) openRead(start,end)
  _getChaptersData() async {
    await Future.delayed(const Duration(milliseconds: 100), () {});
    topSafeHeight = Screen.topSafeHeight;

    try {
      String filePath = widget.filePath;
      RegExp volumeExp = RegExp(
          r'^[\s\t　]*(第?[0-9零一二三四五六七八九十]+卷|卷[0-9零一二三四五六七八九十]+)\s*.{0,20}$',
          unicode: true);
      RegExp chpterExp = RegExp(
          r'^[\s\t　]*第?[0-9零一二三四五六七八九十序百千]+[章节回话]\s*.{0,20}$',
          unicode: true);
      RegExp empty = RegExp(r'^[\s　\t]*$');

      int k = -1;
      bool iscn = false;
      String _full = '';

      final file = new File('$filePath');
      Stream<List<int>> inputStream = file.openRead();

      Utf8Codec _utf8 = Utf8Codec(allowMalformed: true);
      inputStream
          .map((List<int> input) {
            return _book.charset == 'utf8'
                ? input
                : utf8.encode(gbk_bytes.decode(input));
          })
          .transform(_utf8.decoder) // Decode bytes to UTF-8. gbk.decoder
          .transform(new LineSplitter()) // Convert stream to individual lines.
          .listen((String line) {
            if (line == '') {
              return;
            }
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
                  Chapter.fromMap({
                    'name': chapterMatches.elementAt(0).group(0),
                    'isHeader': false,
                    'id': k
                  }));
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
    _curPage = 0;
    var tempContent = _chapters[_curPosition].content;
    var contentHeight = Screen.height -
        topSafeHeight -
        ReaderUtils.topOffset -
        Screen.bottomSafeHeight -
        ReaderUtils.bottomOffset -
        20;
    var contentWidth = Screen.width - 15 - 10;

    setState(() {
      _progress = _curPosition / _chapters.length;
      _content = tempContent;
      _pageOffsets = ReaderPageAgent.getPageOffsets(tempContent, contentHeight,
          contentWidth, _letterSpacing, _lineHeight, _contentFontSize);

      print("阅读位置$_curPosition");
      print("阅读进度$_progress");
      print("页数${_pageOffsets.length}");
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
      _getChaptersData();
    });
  }

  @override
  void dispose() {
    _bookSqlite.close();
    pageController.dispose();
    SystemChrome.setEnabledSystemUIOverlays(
        [SystemUiOverlay.top, SystemUiOverlay.bottom]);
    super.dispose();
  }

  _loadPre() {
    if (_curPosition != 0) {
      _curPosition--;
      _getChapterData();
    }
  }

  _loadNext() {
    if (_curPosition != _chapters.length - 1) {
      _curPosition++;
      _getChapterData();
    }
  }

  previousPage() {
    if (_curPage == 0) {
      if (_curPosition == 0) {
        toast('已经是第一页了');
        return;
      } else {
        _loadPre();
      }
    } else {
      pageController.previousPage(
          duration: Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  nextPage() {
    if (_curPage >= _pageOffsets.length - 1) {
      if (_curPosition == _chapters.length - 1) {
        toast('已经是最后一页了');
        return;
      } else {
        _loadNext();
      }
    } else {
      pageController.nextPage(
          duration: Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  _updateBookMark() {}

  showSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          color: _isDayMode
              ? AppColors.DayModeMenuBgColor
              : AppColors.NightModeMenuBgColor,
          height: 200,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              controlContentTextSize(),
              controlTitleTextSize(),
              controlLineHeight(),
              controlLetterSpace(),
            ],
          ),
        );
      },
    );
  }

  void onChange1(Chapter chapter) {
    if (chapter != null) {
      /*目录跳转*/
      print("目录跳转");
      _curPosition = chapter.isHeader ? chapter.headerId : chapter.id;
      _getChapterData();
    }
  }

  Widget controlContentTextSize() {
    return Container(
      padding: EdgeInsets.only(left: 40, right: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          Expanded(
            child: Text(
              "正文字体",
              style: TextStyle(
                color: _isDayMode
                    ? AppColors.DayModeIconTitleButtonColor
                    : AppColors.NightModeIconTitleButtonColor,
              ),
            ),
            flex: 2,
          ),
          Expanded(
            child: FlatButton(
              child: Icon(
                Icons.remove,
                color: _isDayMode
                    ? AppColors.DayModeIconTitleButtonColor
                    : AppColors.NightModeIconTitleButtonColor,
              ),
              onPressed: () {
                setState(() {
                  _contentFontSize--;
                });
              },
            ),
          ),
          Expanded(
            child: FlatButton(
              child: Icon(
                Icons.add,
                color: _isDayMode
                    ? AppColors.DayModeIconTitleButtonColor
                    : AppColors.NightModeIconTitleButtonColor,
              ),
              onPressed: () {
                setState(() {
                  _contentFontSize++;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget controlTitleTextSize() {
    return Container(
      padding: EdgeInsets.only(left: 40, right: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Text(
              "标题字体",
              style: TextStyle(
                color: _isDayMode
                    ? AppColors.DayModeIconTitleButtonColor
                    : AppColors.NightModeIconTitleButtonColor,
              ),
            ),
            flex: 2,
          ),
          Expanded(
            child: FlatButton(
              child: Icon(
                Icons.remove,
                color: _isDayMode
                    ? AppColors.DayModeIconTitleButtonColor
                    : AppColors.NightModeIconTitleButtonColor,
              ),
              onPressed: () {
                setState(() {
                  _titleFontSize--;
                });
              },
            ),
          ),
          Expanded(
            child: FlatButton(
              child: Icon(
                Icons.add,
                color: _isDayMode
                    ? AppColors.DayModeIconTitleButtonColor
                    : AppColors.NightModeIconTitleButtonColor,
              ),
              onPressed: () {
                setState(() {
                  _titleFontSize++;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget controlLineHeight() {
    return Container(
      padding: EdgeInsets.only(left: 40, right: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Text(
              "行高",
              style: TextStyle(
                color: _isDayMode
                    ? AppColors.DayModeIconTitleButtonColor
                    : AppColors.NightModeIconTitleButtonColor,
              ),
            ),
            flex: 2,
          ),
          Expanded(
            child: FlatButton(
              child: Icon(
                Icons.remove,
                color: _isDayMode
                    ? AppColors.DayModeIconTitleButtonColor
                    : AppColors.NightModeIconTitleButtonColor,
              ),
              onPressed: () {
                setState(() {
                  _lineHeight--;
                });
              },
            ),
          ),
          Expanded(
            child: FlatButton(
              child: Icon(
                Icons.add,
                color: _isDayMode
                    ? AppColors.DayModeIconTitleButtonColor
                    : AppColors.NightModeIconTitleButtonColor,
              ),
              onPressed: () {
                setState(() {
                  _lineHeight++;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget controlLetterSpace() {
    return Container(
      padding: EdgeInsets.only(left: 40, right: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Text(
              "间距",
              style: TextStyle(
                color: _isDayMode
                    ? AppColors.DayModeIconTitleButtonColor
                    : AppColors.NightModeIconTitleButtonColor,
              ),
            ),
            flex: 2,
          ),
          Expanded(
            child: FlatButton(
              child: Icon(
                Icons.remove,
                color: _isDayMode
                    ? AppColors.DayModeIconTitleButtonColor
                    : AppColors.NightModeIconTitleButtonColor,
              ),
              onPressed: () {
                setState(() {
                  _letterSpacing--;
                });
              },
            ),
          ),
          Expanded(
            child: FlatButton(
              child: Icon(
                Icons.add,
                color: _isDayMode
                    ? AppColors.DayModeIconTitleButtonColor
                    : AppColors.NightModeIconTitleButtonColor,
              ),
              onPressed: () {
                setState(() {
                  _letterSpacing++;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _contentView(int page) {
    var offset = _pageOffsets[page];
    var content = _content.substring(offset['start'], offset['end']);
    return Text(
      content,
      style: TextStyle(
        color: _isDayMode
            ? AppColors.DayModeTextColor
            : AppColors.NightModeTextColor,
        height: _lineHeight,
        fontSize: _contentFontSize - 0.5,
        letterSpacing: _letterSpacing,
      ),
    );
  }

  Widget readerOverlayer(int page) {
    var format = DateFormat('HH:mm');
    var time = format.format(DateTime.now());

    return Container(
      padding: EdgeInsets.fromLTRB(
          15, 10 + topSafeHeight, 15, 10 + Screen.bottomSafeHeight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(_chapters[_curPosition].name,
              style: TextStyle(
                fontSize: _titleFontSize,
                color: _isDayMode
                    ? AppColors.DayModeTextColor
                    : AppColors.NightModeTextColor,
              )),
          Expanded(child: Container()),
          Row(
            children: <Widget>[
              BatteryView(),
              SizedBox(width: 10),
              Text(time,
                  style: TextStyle(
                    fontSize: 11,
                    color: _isDayMode
                        ? AppColors.DayModeTextColor
                        : AppColors.NightModeTextColor,
                  )),
              Expanded(child: Container()),
              Text('第${page + 1}/${_pageOffsets.length}页',
                  style: TextStyle(
                    fontSize: 11,
                    color: _isDayMode
                        ? AppColors.DayModeTextColor
                        : AppColors.NightModeTextColor,
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget reader(int page) {
    return Container(
      color: _isDayMode ? AppColors.DayModeBgColor : AppColors.NightModeBgColor,
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,
      child: Stack(
        children: <Widget>[
          readerOverlayer(page),
          Container(
            margin: EdgeInsets.fromLTRB(
                15,
                topSafeHeight + ReaderUtils.topOffset,
                10,
                Screen.bottomSafeHeight + ReaderUtils.bottomOffset),
            child: _contentView(page),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    previousPage();
                  },
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    nextPage();
                  },
                ),
              )
            ],
          ),
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width / 3,
              height: MediaQuery.of(context).size.height,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _updateBookMark();
                    _isShowMenu = !_isShowMenu;
                    _isShowMenu
                        ? SystemChrome.setEnabledSystemUIOverlays(
                            [SystemUiOverlay.top, SystemUiOverlay.bottom])
                        : SystemChrome.setEnabledSystemUIOverlays([]);
                  });
                },
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget iconTitle(
      BuildContext context, IconData iconData, String title, int index) {
    return GestureDetector(
      onTap: () {
        switch (index) {
          case 0:
            Scaffold.of(context).openDrawer();
            break;
          case 1:
            setState(() {
              _isDayMode = !_isDayMode;
            });
            break;
          case 2:
            _isShowMenu = !_isShowMenu;
            _isShowMenu
                ? SystemChrome.setEnabledSystemUIOverlays(
                    [SystemUiOverlay.top, SystemUiOverlay.bottom])
                : SystemChrome.setEnabledSystemUIOverlays([]);
            showSheet(context);
            break;
        }
      },
      child: Container(
        padding: EdgeInsets.only(left: 40, right: 40, bottom: 20, top: 10),
        child: Column(
          children: <Widget>[
            Icon(
              iconData,
              color: _isDayMode
                  ? AppColors.DayModeIconTitleButtonColor
                  : AppColors.NightModeIconTitleButtonColor,
            ),
            Text(
              title,
              style: TextStyle(
                color: _isDayMode
                    ? AppColors.DayModeIconTitleButtonColor
                    : AppColors.NightModeIconTitleButtonColor,
              ),
            ),
          ],
        ),
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
        iconTheme: IconThemeData(
          color: _isDayMode
              ? AppColors.DayModeIconTitleButtonColor
              : AppColors.NightModeIconTitleButtonColor,
        ),
        backgroundColor: _isDayMode
            ? AppColors.DayModeMenuBgColor
            : AppColors.NightModeMenuBgColor,
      ),
    );
  }

  Widget _bottomMenu() {
    return Container(
      width: MediaQuery.of(context).size.width,
      color: _isDayMode
          ? AppColors.DayModeMenuBgColor
          : AppColors.NightModeMenuBgColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              FlatButton(
                onPressed: () {
                  _loadPre();
                },
                child: Text(
                  "上一章",
                  style: TextStyle(
                    color: _isDayMode
                        ? AppColors.DayModeIconTitleButtonColor
                        : AppColors.NightModeIconTitleButtonColor,
                  ),
                ),
              ),
              Container(
                height: 2,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    //未拖动的颜色
                    inactiveTrackColor: _isDayMode
                        ? AppColors.DayModeInactiveTrackColor
                        : AppColors.NightModeInactiveTrackColor,
                    //已拖动的颜色
                    activeTrackColor: _isDayMode
                        ? AppColors.DayModeActiveTrackColor
                        : AppColors.NightModeActiveTrackColor,
                    //滑块颜色
                    thumbColor: _isDayMode
                        ? AppColors.DayModeActiveTrackColor
                        : AppColors.NightModeActiveTrackColor,
                  ),
                  child: Slider(
                    value: _progress,
                    onChanged: (value) {
                      setState(() {
//                        print(value);
//                        _progress = value;
//                        _curPosion = (value * _chapters.length).floor();
//                        _getChapterData();
                      });
                    },
                  ),
                ),
              ),
              FlatButton(
                onPressed: () {
                  _loadNext();
                },
                child: Text(
                  "下一章",
                  style: TextStyle(
                    color: _isDayMode
                        ? AppColors.DayModeIconTitleButtonColor
                        : AppColors.NightModeIconTitleButtonColor,
                  ),
                ),
              )
            ],
          ),
          Builder(
            builder: (context) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                iconTitle(context, Icons.menu, "目录", 0),
                iconTitle(context, Icons.tonality, _isDayMode ? "夜间" : "日间", 1),
                iconTitle(context, Icons.text_format, "设置", 2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  onPageChanged(int index) {
    setState(() {
      _curPage = index;
    });
  }

  Widget buildPage(BuildContext context, int index) {
    return reader(index);
  }

  Widget buildPageView() {
    return PageView.builder(
      physics: BouncingScrollPhysics(),
      controller: pageController,
      itemCount: _pageOffsets.length,
      itemBuilder: buildPage,
      onPageChanged: onPageChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _content == ''
        ? LoadingPage()
        : Scaffold(
            backgroundColor: _isDayMode
                ? AppColors.DayModeBgColor
                : AppColors.NightModeBgColor,
            drawer: new Drawer(
              child: CatalogPageLocal(
                widget.filePath,
                _chapters,
                callBack1: (Chapter chapter) => onChange1(chapter),
              ),
            ),
            body: Stack(
              children: <Widget>[
                buildPageView(),
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
