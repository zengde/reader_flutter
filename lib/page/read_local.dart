import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reader_flutter/bean/book.dart';
import 'package:reader_flutter/bean/mark.dart';
import 'package:reader_flutter/bean/volume.dart';
import 'package:reader_flutter/page/reader/reader_config.dart';
import 'package:reader_flutter/util/screen.dart';
import 'package:reader_flutter/util/util.dart';
import 'package:reader_flutter/view/load.dart';
import 'catalog_local.dart';
import 'reader/reader_menu.dart';
import 'reader/reader_view.dart';
import 'reader/reader_engine.dart';

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

  bool _isShowMenu = false;
  int _curPosition = 0;
  Book _book;

  int _curPage = 0;
  double topSafeHeight = 0;

  int _realPage = 10000;
  int _realOffset = 0;
  PageController _controller;
  int get chapterCount =>
      lightEngine != null && lightEngine.mChapterList != null
          ? lightEngine.chapterCount
          : 0;

  final GlobalKey<ScaffoldState> scaffoldKey = new GlobalKey<ScaffoldState>();
  ReaderEngine lightEngine;
  bool isClose = false;

  _getChaptersData() async {
    await Future.delayed(const Duration(milliseconds: 100), () {});
    topSafeHeight = Screen.topSafeHeight;
    lightEngine = new ReaderEngine(
        book: _book, stateSetter: setState, topSafeHeight: topSafeHeight);
    await lightEngine.refreshChapterList();
    _getChapterData(_curPosition);
  }

  _getChapterData(int position) {
    if (isClose) return;
    setState(() {
      print("阅读位置$_curPosition");
      print("页数${curArticle.pageCount}");
    });
    if (_curPosition != position) {
      _curPosition = position;
      _realOffset = 0;
      _curPage = 0;
      _updateReadProgress();
    }
  }

  @override
  void initState() {
    super.initState();

    /*查询是否已添加*/
    _bookSqlite.getBook(0, path: widget.filePath).then((b) {
      if (b != null) {
        _book = b;
        _curPosition = _book.position;
      }
      _getChaptersData();
    });
  }

  @override
  void dispose() {
    isClose = true;
    _bookSqlite.close();
    _controller?.dispose();
    SystemChrome.setEnabledSystemUIOverlays(
        [SystemUiOverlay.top, SystemUiOverlay.bottom]);
    lightEngine?.close();
    super.dispose();
  }

  previousPage() {
    _controller.previousPage(
        duration: Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  nextPage() {
    _controller.nextPage(
        duration: Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _updateReadProgress() {
    /*更新阅读进度*/
    _book.position = _curPosition;
    _book.lastChapter = curArticle.name;
    _book.lastChapterId = curArticle.index.toString();
    _bookSqlite.update(_book).then((ret) {
      if (ret == 1) {
        print("更新阅读进度${_book.position}");
      }
    });
  }

  showSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          color: ReaderConfig.instance.menuBgColor,
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
      var curPosition = chapter.isHeader ? chapter.headerId : chapter.index;
      _getChapterData(curPosition);
    }
  }

  void onChange2(BookMark bookMark) {
    setState(() {
      if (bookMark != null) {
        var curPosition = bookMark.chapterId;
        _getChapterData(curPosition);
      }
    });
  }

  onPageChanged(int page) {
    int index = getRealIndex(page);
    if (index == curArticle.pageCount) {
      //到达最后一章了
      if (_curPosition == chapterCount - 1) {
        previousPage();
      } else {
        _realOffset += curArticle.pageCount;
        _curPosition++;
      }
    } else if (index < 0) {
      //到达第一章了
      if (_curPosition == 0) {
        nextPage();
      } else {
        _realOffset -= preArticle.pageCount;
        _curPosition--;
      }
    }
    print(_curPosition);
  }

  Chapter get preArticle {
    return lightEngine[_curPosition - 1];
  }

  Chapter get curArticle {
    return lightEngine[_curPosition];
  }

  Chapter get nextArticle {
    return lightEngine[_curPosition + 1];
  }

  Map<String, dynamic> getRealAricle(int index) {
    int offset = getRealIndex(index);
    Map<String, dynamic> res = {};
    res['chapter'] = curArticle;
    res['page'] = offset;

    if (offset == curArticle.pageCount) {
      res['chapter'] = nextArticle;
      res['page'] = 0;
    }
    if (offset < 0) {
      res['chapter'] = preArticle;
      res['page'] = preArticle == null ? 0 : preArticle.pageCount - 1;
    }
    return res;
  }

  PageController get controller {
    if (_controller == null) {
      _controller = PageController(
        initialPage: _realPage + _curPage,
      );
    }
    return _controller;
  }

  dynamic getRealIndex(dynamic position) {
    final dynamic offset = position - _realOffset - _realPage;
    return offset;
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
                color: ReaderConfig.instance.btnColor,
              ),
            ),
            flex: 2,
          ),
          Expanded(
            child: FlatButton(
              child: Icon(
                Icons.remove,
                color: ReaderConfig.instance.btnColor,
              ),
              onPressed: () {
                setState(() {
                  ReaderConfig.instance.contentFontSize--;
                });
              },
            ),
          ),
          Expanded(
            child: FlatButton(
              child: Icon(
                Icons.add,
                color: ReaderConfig.instance.btnColor,
              ),
              onPressed: () {
                setState(() {
                  ReaderConfig.instance.contentFontSize++;
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
                color: ReaderConfig.instance.btnColor,
              ),
            ),
            flex: 2,
          ),
          Expanded(
            child: FlatButton(
              child: Icon(
                Icons.remove,
                color: ReaderConfig.instance.btnColor,
              ),
              onPressed: () {
                setState(() {
                  ReaderConfig.instance.titleFontSize--;
                });
              },
            ),
          ),
          Expanded(
            child: FlatButton(
              child: Icon(
                Icons.add,
                color: ReaderConfig.instance.btnColor,
              ),
              onPressed: () {
                setState(() {
                  ReaderConfig.instance.titleFontSize++;
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
                color: ReaderConfig.instance.btnColor,
              ),
            ),
            flex: 2,
          ),
          Expanded(
            child: FlatButton(
              child: Icon(
                Icons.remove,
                color: ReaderConfig.instance.btnColor,
              ),
              onPressed: () {
                setState(() {
                  ReaderConfig.instance.lineHeight--;
                });
              },
            ),
          ),
          Expanded(
            child: FlatButton(
              child: Icon(
                Icons.add,
                color: ReaderConfig.instance.btnColor,
              ),
              onPressed: () {
                setState(() {
                  ReaderConfig.instance.lineHeight++;
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
                color: ReaderConfig.instance.btnColor,
              ),
            ),
            flex: 2,
          ),
          Expanded(
            child: FlatButton(
              child: Icon(
                Icons.remove,
                color: ReaderConfig.instance.btnColor,
              ),
              onPressed: () {
                setState(() {
                  ReaderConfig.instance.letterSpacing--;
                });
              },
            ),
          ),
          Expanded(
            child: FlatButton(
              child: Icon(
                Icons.add,
                color: ReaderConfig.instance.btnColor,
              ),
              onPressed: () {
                setState(() {
                  ReaderConfig.instance.letterSpacing++;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  onTap(Offset position) async {
    double xRate = position.dx / Screen.width;
    if (xRate > 0.33 && xRate < 0.66) {
      SystemChrome.setEnabledSystemUIOverlays(
          [SystemUiOverlay.top, SystemUiOverlay.bottom]);
      setState(() {
        _isShowMenu = true;
      });
    } else if (xRate >= 0.66) {
      nextPage();
    } else {
      previousPage();
    }
  }

  Widget buildPage(BuildContext context, int index) {
    var res = getRealAricle(index);
    print('itemBuilder-' + index.toString());

    if (res['chapter'] == null) {
      return Container();
    }
    return GestureDetector(
      onTapUp: (TapUpDetails details) {
        onTap(details.globalPosition);
      },
      child: ReaderView(
          chapter: res['chapter'],
          page: res['page'],
          topSafeHeight: topSafeHeight),
    );
  }

  Widget buildPageView() {
    return new PageView.builder(
      physics: BouncingScrollPhysics(),
      controller: controller,
      itemCount: null,
      itemBuilder: buildPage,
      onPageChanged: onPageChanged,
    );
  }

  buildMenu() {
    if (!_isShowMenu) {
      return Container();
    }
    return ReaderMenu(
      book: _book,
      chapters: lightEngine.mChapterList,
      articleIndex: curArticle.index,
      onTap: hideMenu,
      onPreviousArticle: () {
        _getChapterData(curArticle.preId);
      },
      onNextArticle: () {
        _getChapterData(curArticle.nextId);
      },
      onToggleChapter: (Chapter chapter) {
        _getChapterData(chapter.index);
      },
      onTapMenu: tapMenu,
    );
  }

  hideMenu() {
    SystemChrome.setEnabledSystemUIOverlays([]);
    setState(() {
      this._isShowMenu = false;
    });
  }

  tapMenu(int index) {
    switch (index) {
      case 0:
        scaffoldKey.currentState.openDrawer();
        break;
      case 1:
        setState(() {
          ReaderConfig.instance.isDayMode = !ReaderConfig.instance.isDayMode;
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
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (chapterCount == 0) {
      return LoadingPage();
    }

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: ReaderConfig.instance.bgColor,
      drawer: new Drawer(
        child: CatalogPageLocal(
          _book,
          lightEngine.mChapterList,
          callBack1: (Chapter chapter) => onChange1(chapter),
          callBack2: (BookMark bookMark) => onChange2(bookMark),
        ),
      ),
      body: Stack(children: <Widget>[
        buildPageView(),
        buildMenu(),
      ]),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
