import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reader_flutter/bean/book.dart';
import 'package:reader_flutter/bean/mark.dart';
import 'package:reader_flutter/bean/volume.dart';
import 'package:reader_flutter/page/reader/reader_config.dart';
import 'package:reader_flutter/page/reader/reader_page_agent.dart';
import 'package:reader_flutter/util/screen.dart';
import 'package:reader_flutter/util/util.dart';
import 'package:reader_flutter/view/load.dart';
/*
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
*/

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

  final BookMarkSqlite _bookMarkSqlite = BookMarkSqlite();

  bool _isShowMenu = false;
  int _curPosition = 0;
  List<Volume> _volumes = [];
  List<Chapter> _chapters = [];
  Book _book;
  bool _isAdd = false;

  int _curPage = 0;
  double topSafeHeight = 0;
  PageController pageController = PageController(keepPage: false);
  Chapter currentArticle;
  Chapter preArticle;
  Chapter nextArticle;
  final GlobalKey<ScaffoldState> scaffoldKey = new GlobalKey<ScaffoldState>();

  // _getChaptersData(start,end) openRead(start,end)
  _getChaptersData() async {
    await Future.delayed(const Duration(milliseconds: 100), () {});
    topSafeHeight = Screen.topSafeHeight;
    print('start' + DateTime.now().toString());
    // compute延迟
    _chapters = await compute(decodeText, {'filePath': widget.filePath, 'charSet': _book.charset});
    //_chapters = decodeText({'filePath': widget.filePath, 'charSet': _book.charset});
    print('end' + DateTime.now().toString());
    _getChapterData(_curPosition, PageJumpType.stay);
  }

  _getChapterData(int chapterId, PageJumpType jumpType) {
    currentArticle = fetchChapter(chapterId);
    if (chapterId > 0) {
      preArticle = fetchChapter(chapterId - 1);
    } else {
      preArticle = null;
    }
    if (chapterId < _chapters.length - 1) {
      nextArticle = fetchChapter(chapterId + 1);
    } else {
      nextArticle = null;
    }
    if (jumpType == PageJumpType.firstPage) {
      _curPage = 0;
    } else if (jumpType == PageJumpType.lastPage) {
      _curPage = currentArticle.pageCount - 1;
    }
    if (jumpType != PageJumpType.stay) {
      pageController.jumpToPage(
          (preArticle != null ? preArticle.pageCount : 0) + _curPage);
    }

    setState(() {
      print("阅读位置$_curPosition");
      print("页数${currentArticle.pageCount}");
      print(DateTime.now());
    });
  }

  Chapter fetchChapter(int chapterId) {
    if (chapterId > _chapters.length - 1) {
      return null;
    }
    var tempContent = _chapters[chapterId].content;
    if (_chapters[chapterId].pageCount == null) {
      _chapters[chapterId].pageOffsets =
          ReaderPageAgent.getPageOffsets(tempContent, topSafeHeight);
    }
    return _chapters[chapterId];
  }

  @override
  void initState() {
    super.initState();
    pageController.addListener(onScroll);

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

  _loadPre(int chapterId) {
    if (preArticle != null || chapterId == 0) {
      return;
    }
    preArticle = fetchChapter(chapterId);
    pageController.jumpToPage(preArticle.pageCount + _curPage);
    setState(() {});
  }

  _loadNext(int chapterId) {
    if (nextArticle != null || chapterId == 0) {
      return;
    }
    nextArticle = fetchChapter(chapterId);
    setState(() {});
  }

  previousPage() {
    if (_curPage == 0 && currentArticle.id == 0) {
      toast('已经是第一页了');
      return;
    }
    pageController.previousPage(
        duration: Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  nextPage() {
    if (_curPage >= currentArticle.pageCount - 1 &&
        currentArticle.id == _chapters.length - 1) {
      toast('已经是最后一页了');
      return;
    }
    pageController.nextPage(
        duration: Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  _updateBookMark() {}

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
      _curPosition = chapter.isHeader ? chapter.headerId : chapter.id;
      _getChapterData(_curPosition, PageJumpType.firstPage);
    }
  }

  onPageChanged(int index) {
    var page = index - (preArticle != null ? preArticle.pageCount : 0);
    if (page < currentArticle.pageCount && page >= 0) {
      setState(() {
        _curPage = page;
      });
    }
  }

  onScroll() {
    var page = pageController.offset / Screen.width;

    var nextArtilePage = currentArticle.pageCount +
        (preArticle != null ? preArticle.pageCount : 0);
    if (page >= nextArtilePage) {
      print('到达下个章节了');

      preArticle = currentArticle;
      currentArticle = nextArticle;
      nextArticle = null;
      _curPage = 0;
      pageController.jumpToPage(preArticle.pageCount);
      _loadNext(currentArticle.id + 1);
      setState(() {});
    }
    if (preArticle != null && page <= preArticle.pageCount - 1) {
      print('到达上个章节了');

      nextArticle = currentArticle;
      currentArticle = preArticle;
      preArticle = null;
      _curPage = currentArticle.pageCount - 1;
      pageController.jumpToPage(currentArticle.pageCount - 1);
      _loadPre(currentArticle.id - 1);
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
    if (currentArticle == null) {
      return Container();
    }

    int itemCount = (preArticle != null ? preArticle.pageCount : 0) +
        currentArticle.pageCount +
        (nextArticle != null ? nextArticle.pageCount : 0);
    print('build page');
    print(DateTime.now());
    return PageView.builder(
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
      chapters: _chapters,
      articleIndex: currentArticle.id,
      onTap: hideMenu,
      onPreviousArticle: () {
        _getChapterData(currentArticle.id - 1, PageJumpType.firstPage);
      },
      onNextArticle: () {
        _getChapterData(currentArticle.id + 1, PageJumpType.firstPage);
      },
      onToggleChapter: (Chapter chapter) {
        _getChapterData(chapter.id, PageJumpType.firstPage);
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
    if (currentArticle == null || _chapters == null) {
      return LoadingPage();
    }

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: ReaderConfig.instance.bgColor,
      drawer: new Drawer(
        child: CatalogPageLocal(
          widget.filePath,
          _chapters,
          callBack1: (Chapter chapter) => onChange1(chapter),
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
