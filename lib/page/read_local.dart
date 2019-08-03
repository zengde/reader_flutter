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

enum PageJumpType { stay, firstPage, lastPage }

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
  PageController pageController = PageController(keepPage: false);
  Chapter currentArticle;
  Chapter preArticle;
  Chapter nextArticle;
  final GlobalKey<ScaffoldState> scaffoldKey = new GlobalKey<ScaffoldState>();
  ReaderEngine lightEngine;

  _getChaptersData() async {
    await Future.delayed(const Duration(milliseconds: 100), () {});
    topSafeHeight = Screen.topSafeHeight;
    print('start' + DateTime.now().toString());
    lightEngine = new ReaderEngine(
        book: _book, stateSetter: setState, topSafeHeight: topSafeHeight);
    await lightEngine.refreshChapterList();
    print('end' + DateTime.now().toString());
    _getChapterData(_curPosition, PageJumpType.stay);
    if (_curPosition != 0) {
      //_getChapterData(_curPosition, PageJumpType.firstPage);
    }
  }

  _getChapterData(int position, PageJumpType jumpType) {
    currentArticle = lightEngine[position];
    preArticle = lightEngine[position - 1];
    nextArticle = lightEngine[position + 1];
    if (jumpType == PageJumpType.firstPage) {
      _curPage = 0;
    } else if (jumpType == PageJumpType.lastPage) {
      _curPage = currentArticle.pageCount - 1;
    }
    if (jumpType != PageJumpType.stay && pageController.hasClients) {
      pageController.jumpToPage(
          (preArticle != null ? preArticle.pageCount : 0) + _curPage);
    }
    setState(() {
      print("阅读位置$_curPosition");
      print("页数${currentArticle.pageCount}");
    });
    if (_curPosition != position) {
      _curPosition = position;
      _updateReadProgress();
    }
  }

  @override
  void initState() {
    super.initState();
    pageController.addListener(onScroll);

    /*查询是否已添加*/
    _bookSqlite.getBook(0, path: widget.filePath).then((b) {
      if (b != null) {
        _book = b;
        //_curPosition = _book.position;
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
    lightEngine.close();
    super.dispose();
  }

  previousPage() {
    if (_curPage == 0 && currentArticle.index == 0) {
      toast('已经是第一页了');
      return;
    }
    pageController.previousPage(
        duration: Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  nextPage() {
    if (_curPage >= currentArticle.pageCount - 1 &&
        currentArticle.index == lightEngine.chapterCount - 1) {
      toast('已经是最后一页了');
      return;
    }
    pageController.nextPage(
        duration: Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _updateReadProgress() {
    /*更新阅读进度*/
    _book.position = _curPosition;
    _book.lastChapter = currentArticle.name;
    _book.lastChapterId = currentArticle.index.toString();
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
      _getChapterData(curPosition, PageJumpType.firstPage);
    }
  }

  void onChange2(BookMark bookMark) {
    setState(() {
      if (bookMark != null) {
        var curPosition = bookMark.chapterId;
        _getChapterData(curPosition, PageJumpType.firstPage);
      }
    });
  }

  onPageChanged(int index) {
    var page = index - (preArticle != null ? preArticle.pageCount : 0);
    _curPage = page;
  }

  onScroll() {
    var page = pageController.page;
    var nextArtilePage = currentArticle.pageCount +
        (preArticle != null ? preArticle.pageCount : 0);
    if (page >= nextArtilePage) {
      print('到达下个章节了');

      preArticle = currentArticle;
      currentArticle = nextArticle;
      nextArticle = lightEngine[currentArticle.nextId];
      _curPage = 0;
      pageController.jumpToPage(preArticle.pageCount);
      setState(() {});
    } else if (preArticle != null && page <= preArticle.pageCount - 1) {
      print('到达上个章节了');

      nextArticle = currentArticle;
      currentArticle = preArticle;
      preArticle = lightEngine[currentArticle.preId];
      _curPage = currentArticle.pageCount - 1;
      pageController.jumpToPage(_curPage);
      if (preArticle != null)
        pageController.jumpToPage(preArticle.pageCount + _curPage);
      setState(() {});
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
    var page = index - (preArticle != null ? preArticle.pageCount : 0);
    var article;
    if (page >= this.currentArticle.pageCount) {
      // 到达下一章了
      article = nextArticle;
      page = 0;
    } else if (page < 0) {
      // 到达上一章了
      article = preArticle;
      page = preArticle.pageCount - 1;
    } else {
      article = this.currentArticle;
    }
    return GestureDetector(
      onTapUp: (TapUpDetails details) {
        onTap(details.globalPosition);
      },
      child: ReaderView(
          chapter: article, page: page, topSafeHeight: topSafeHeight),
    );
  }

  Widget buildPageView() {
    int itemCount = (preArticle != null ? preArticle.pageCount : 0) +
        currentArticle.pageCount +
        (nextArticle != null ? nextArticle.pageCount : 0);
    return new PageView.builder(
      physics: BouncingScrollPhysics(),
      controller: pageController,
      itemCount: itemCount,
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
      articleIndex: currentArticle.index,
      onTap: hideMenu,
      onPreviousArticle: () {
        _getChapterData(currentArticle.preId, PageJumpType.firstPage);
      },
      onNextArticle: () {
        _getChapterData(currentArticle.nextId, PageJumpType.firstPage);
      },
      onToggleChapter: (Chapter chapter) {
        _getChapterData(chapter.index, PageJumpType.firstPage);
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
    if (currentArticle == null) {
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
