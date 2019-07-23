import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:reader_flutter/bean/book.dart';
import 'package:reader_flutter/bean/mark.dart';
import 'package:reader_flutter/bean/volume.dart';
import 'package:reader_flutter/page/reader/reader_config.dart';
import 'package:reader_flutter/util/screen.dart';
import 'package:reader_flutter/util/sq_color.dart';
import 'dart:async';

import 'package:reader_flutter/util/util.dart';

class ReaderMenu extends StatefulWidget {
  final List<Chapter> chapters;
  final int articleIndex;

  final VoidCallback onTap;
  final void Function(int index) onTapMenu;
  final VoidCallback onPreviousArticle;
  final VoidCallback onNextArticle;
  final void Function(Chapter chapter) onToggleChapter;

  ReaderMenu(
      {this.chapters,
      this.articleIndex,
      this.onTap,
      this.onPreviousArticle,
      this.onNextArticle,
      this.onToggleChapter,
      this.onTapMenu});

  @override
  _ReaderMenuState createState() => _ReaderMenuState();
}

class _ReaderMenuState extends State<ReaderMenu>
    with SingleTickerProviderStateMixin {
  AnimationController animationController;
  Animation<double> animation;

  double progressValue;
  bool isTipVisible = false;
  bool _isMark = false;
  final BookMarkSqlite _bookMarkSqlite = BookMarkSqlite();

  @override
  initState() {
    super.initState();

    progressValue =
        this.widget.articleIndex / (this.widget.chapters.length - 1);
    animationController = AnimationController(
        duration: const Duration(milliseconds: 200), vsync: this);
    animation = Tween(begin: 0.0, end: 1.0).animate(animationController);
    animation.addListener(() {
      setState(() {});
    });
    animationController.forward();
  }

  @override
  void didUpdateWidget(ReaderMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    progressValue =
        this.widget.articleIndex / (this.widget.chapters.length - 1);
  }
  
  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  hide() {
    animationController.reverse();
    Timer(Duration(milliseconds: 200), () {
      this.widget.onTap();
    });
    setState(() {
      isTipVisible = false;
    });
  }

  tapMenu(int index) {
    animationController.reverse();
    Timer(Duration(milliseconds: 200), () {
      this.widget.onTapMenu(index);
    });
    setState(() {
      isTipVisible = false;
    });
  }

  buildTopView(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: Screen.navigationBarHeight,
        width: MediaQuery.of(context).size.width,
        child: AppBar(
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          actions: <Widget>[
            widget.chapters[widget.articleIndex].isHeader
                ? Container()
                : IconButton(
                    icon:
                        Icon(_isMark ? Icons.bookmark : Icons.bookmark_border),
                    onPressed: () {
                      Chapter chapter = widget.chapters[widget.articleIndex];
                      /*
                      if (!_isAdd) {
                        toast("请先添加到书架");
                      } else if (_isAdd && !_isMark) {
                        BookMark bookMark = BookMark();
                        bookMark.bookId = widget.bookId;
                        bookMark.chapterName = chapter.name;
                        bookMark.chapterId = chapter.id;
                        var now = new DateTime.now();
                        var formatter = DateFormat('yyyy-MM-dd  HH:mm:ss');
                        bookMark.addTime = formatter.format(now);
                        bookMark.desc = "";
                        _bookMarkSqlite.insert(bookMark);
                      } else if (_isMark) {
                        _bookMarkSqlite.deleteByChapterId(chapter.id);
                      }
                      _updateBookMark();*/
                    },
                  )
          ],
          iconTheme: IconThemeData(
            color: ReaderConfig.instance.btnColor,
          ),
          backgroundColor: ReaderConfig.instance.menuBgColor,
        ),
      ),
    );
  }

  int currentArticleIndex() {
    return ((this.widget.chapters.length - 1) * progressValue).toInt();
  }

  buildProgressTipView() {
    if (!isTipVisible) {
      return Container();
    }
    Chapter chapter = this.widget.chapters[currentArticleIndex()];

    double percentage =
        currentArticleIndex() / (this.widget.chapters.length - 1) * 100;
    return Container(
      decoration: BoxDecoration(
          color: Color(0xff00C88D), borderRadius: BorderRadius.circular(5)),
      margin: EdgeInsets.fromLTRB(15, 0, 15, 10),
      padding: EdgeInsets.all(15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(chapter.name,
              style: TextStyle(color: Colors.white, fontSize: 16)),
          Text('${percentage.toStringAsFixed(1)}%',
              style: TextStyle(color: SQColor.lightGray, fontSize: 12)),
        ],
      ),
    );
  }

  previousArticle() {
    if (this.widget.articleIndex == 0) {
      toast('已经是第一章了');
      return;
    }
    this.widget.onPreviousArticle();
    setState(() {
      isTipVisible = true;
    });
  }

  nextArticle() {
    if (this.widget.articleIndex == this.widget.chapters.length - 1) {
      toast('已经是最后一章了');
      return;
    }
    this.widget.onNextArticle();
    setState(() {
      isTipVisible = true;
    });
  }

  buildProgressView() {
    return Container(
      padding: EdgeInsets.fromLTRB(5, 0, 5, 0),
      child: Row(
        children: <Widget>[
          FlatButton(
            onPressed: previousArticle,
            child: Text(
              "上一章",
              style: TextStyle(
                color: ReaderConfig.instance.btnColor,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                //未拖动的颜色
                inactiveTrackColor: ReaderConfig.instance.inactiveTrackColor,
                //已拖动的颜色
                activeTrackColor: ReaderConfig.instance.activeTrackColor,
                //滑块颜色
                thumbColor: ReaderConfig.instance.thumbColor,
              ),
              child: Slider(
                value: progressValue,
                onChanged: (value) {
                  setState(() {
                    isTipVisible = true;
                    progressValue = value;
                  });
                },
                onChangeEnd: (double value) {
                  Chapter chapter = this.widget.chapters[currentArticleIndex()];
                  this.widget.onToggleChapter(chapter);
                },
              ),
            ),
          ),
          FlatButton(
            onPressed: nextArticle,
            child: Text(
              "下一章",
              style: TextStyle(
                color: ReaderConfig.instance.btnColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  buildBottomView() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Column(
        children: <Widget>[
          buildProgressTipView(),
          Container(
            color: ReaderConfig.instance.menuBgColor,
            padding: EdgeInsets.only(bottom: Screen.bottomSafeHeight),
            child: Column(
              children: <Widget>[
                buildProgressView(),
                buildBottomMenus(),
              ],
            ),
          )
        ],
      ),
    );
  }

  buildBottomMenus() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: <Widget>[
        buildBottomItem('目录', Icons.menu, 0),
        buildBottomItem(
            ReaderConfig.instance.isDayMode ? "夜间" : "日间", Icons.tonality, 1),
        buildBottomItem('设置', Icons.text_format, 2),
      ],
    );
  }

  buildBottomItem(String title, IconData iconData, int index) {
    return GestureDetector(
      onTap: () {
        tapMenu(index);
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 7),
        child: Column(
          children: <Widget>[
            Icon(
              iconData,
              color: ReaderConfig.instance.btnColor,
            ),
            SizedBox(height: 5),
            Text(
              title,
              style: TextStyle(
                color: ReaderConfig.instance.btnColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Stack(
        children: <Widget>[
          GestureDetector(
            onTapDown: (_) {
              hide();
            },
            child: Container(color: Colors.transparent),
          ),
          buildTopView(context),
          buildBottomView(),
        ],
      ),
    );
  }
}
