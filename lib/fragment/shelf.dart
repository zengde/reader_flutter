import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:reader_flutter/bean/book.dart';
import 'package:reader_flutter/bean/info.dart';
import 'package:reader_flutter/page/read.dart';
import 'package:reader_flutter/page/read_local.dart';
import 'package:reader_flutter/util/constants.dart';
import 'package:reader_flutter/util/http_manager.dart';

class BookShelf extends StatefulWidget {
  @override
  _BookShelfState createState() => _BookShelfState();
}

class _BookShelfState extends State<BookShelf> {
  List<Book> _books = [];
  final BookSqlite bookSqlite = BookSqlite();
  bool isListStyle = true;

  @override
  void initState() {
    super.initState();
    _queryAll(true);
  }

  @override
  void dispose() {
    bookSqlite.close();
    super.dispose();
  }

  _queryAll(bool flag) async {
    print("查询");
    _books.clear();
    bookSqlite.queryAll().then(
      (books) {
        if (books != null)
          setState(
            () {
              print("共${books.length}本书");
              _books.addAll(books);
              if (flag) _onRefresh();
            },
          );
      },
    );
  }

  Widget buildShelfItemView(int index) {
    Book book;
    if (index == _books.length) {
      book = new Book();
      book.name = '添加书籍';
      book.author = '';
      book.img = 'assets/images/bookshelf_add.png';
      book.updateTime = '';
      book.isLocal = true;
      book.lastChapter = '';
      return InkWell(
        onTap: () {
          Navigator.of(context).pushNamed('/importLocal');
        },
        child: bookShelfItem(book),
      );
    }
    book = _books[index];
    return InkWell(
      onLongPress: () {
        showAlertDialog(book);
      },
      onTap: () {
        Navigator.push(context,
            MaterialPageRoute(builder: (BuildContext context) {
          return book.isLocal ? ReadPageLocal(book.path) : ReadPage(book.id);
        }));
      },
      highlightColor: Colors.black12,
      child: bookShelfItem(book),
    );
  }

  Widget buildShelfItemViewGrid() {
    List<Widget> children = [];
    _books.forEach((novel) {
      children.add(bookShelfItemGrid(novel));
    });
    var width = (MediaQuery.of(context).size.width - 15 * 2 - 24 * 2) / 3;
    children.add(GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed('/importLocal');
      },
      child: Container(
        width: width,
        height: width / 0.75,
        child: Image.asset('assets/images/bookshelf_add.png'),
      ),
    ));
    return Container(
      padding: EdgeInsets.fromLTRB(15, 20, 15, 15),
      child: Wrap(
        spacing: 23,
        children: children,
      ),
    );
  }

  Widget bookShelfItemGrid(Book book) {
    var width = (MediaQuery.of(context).size.width - 15 * 2 - 24 * 2) / 3;
    return GestureDetector(
      onTap: () {
        Navigator.push(context,
            MaterialPageRoute(builder: (BuildContext context) {
          return book.isLocal ? ReadPageLocal(book.path) : ReadPage(book.id);
        }));
      },
      child: Container(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DecoratedBox(
              child: book.isLocal
                  ? Image.asset(
                      book.img,
                      width: width,
                      height: width / 0.75,
                    )
                  : CachedNetworkImage(
                      imageUrl: book.img,
                      width: width,
                      height: width / 0.75,
                      placeholder: (context, url) =>
                          new CircularProgressIndicator(),
                      errorWidget: (context, url, error) =>
                          new Icon(Icons.error),
                    ),
              decoration: BoxDecoration(boxShadow: [
                BoxShadow(color: Color(0x22000000), blurRadius: 5)
              ]),
            ),
            SizedBox(height: 10),
            Text(book.name,
                style: TextStyle(fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(
              '已读 1%',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
            SizedBox(height: 25),
          ],
        ),
      ),
    );
  }

  Widget bookShelfItem(Book book) {
    List<Widget> children = [
      ClipRRect(
        borderRadius: BorderRadius.circular(2.0),
        child: book.isLocal
            ? Image.asset(
                book.img,
                fit: BoxFit.cover,
                width: 80,
                height: 100,
              )
            : CachedNetworkImage(
                fit: BoxFit.cover,
                imageUrl: book.img,
                width: 80,
                height: 100,
              ),
      ),
      Expanded(
        child: Container(
          padding: EdgeInsets.only(left: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                book.name,
                style: TextStyle(
                    fontWeight: FontWeight.w100,
                    color: Colors.black,
                    fontSize: 16.0),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              Text(
                book.author,
                style: TextStyle(
                    fontWeight: FontWeight.w100,
                    color: Colors.black,
                    fontSize: 14.0),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              Text(
                book.lastChapter,
                style: TextStyle(
                    fontWeight: FontWeight.w100,
                    color: Colors.black,
                    fontSize: 14.0),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              Text(
                book.updateTime,
                style: TextStyle(
                    fontWeight: FontWeight.w100,
                    color: Colors.black,
                    fontSize: 14.0),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    ];
    return Container(
        margin: EdgeInsets.only(left: 15, right: 15, top: 10, bottom: 10),
        height: 100.0,
        child: Row(
          children: children,
        ));
  }

  void showAlertDialog(Book book) {
    showDialog(
        context: context,
        builder: (_) => new AlertDialog(
                title: new Text("提示"),
                content: new Column(
                  children: <Widget>[
                    new Text("是否删除 ${book.name}?"),
                    book.isLocal
                        ? CheckboxListTile(
                            title: Text("是否同时删除本地文件?"),
                            value: true,
                            onChanged: (val) {},
                          )
                        : Container(),
                  ],
                ),
                actions: <Widget>[
                  new FlatButton(
                    child: new Text("返回"),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  new FlatButton(
                    child: new Text("确定"),
                    onPressed: () {
                      setState(() {
                        bookSqlite.delete(book.id);
                        Navigator.of(context).pop();
                        _queryAll(false);
                      });
                    },
                  )
                ]));
  }

  Future<void> _onRefresh() async {
    _books.forEach((book) {
      if (!book.isLocal) _getInfoData(book.id);
    });
    return;
  }

  _getInfoData(int bookId) {
    getInfoData(bookId).then((map) {
      if (map['data'] != null) {
        BookInfo _bookInfo = BookInfo.fromMap(map['data']);
        print("更新");
        bookSqlite.getBook(_bookInfo.Id).then((book) {
          Book _book = Book();
          _book.id = _bookInfo.Id;
          _book.position = book.position;
          _book.name = _bookInfo.Name.toString();
          _book.desc = _bookInfo.Desc.toString();
          _book.img = _bookInfo.Img.toString();
          _book.author = _bookInfo.Author.toString();
          _book.updateTime = _bookInfo.LastTime.toString();
          _book.lastChapter = _bookInfo.LastChapter.toString();
          _book.lastChapterId = _bookInfo.LastChapterId.toString();
          _book.cname = _bookInfo.CName.toString();
          _book.bookStatus = _bookInfo.BookStatus.toString();
          bookSqlite.update(_book).then((ret) {});
        });
      }
    });
  }

  PopupMenuItem<String> _buildPopupMenuItem(
      String path, String text, IconData icon) {
    return new PopupMenuItem<String>(
      value: path,
      child: Row(children: <Widget>[
        Padding(
            padding: EdgeInsets.fromLTRB(0.0, 0.0, 8.0, 0.0),
            child: Icon(icon)),
        Text(text)
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text("书架"),
        actions: <Widget>[
          IconButton(
            icon: Icon(MyIcons.searchIcon),
            onPressed: () {
              Navigator.of(context).pushNamed('/search');
            },
          ),
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () async {
              final result = await showMenu(
                context: context,
                position: RelativeRect.fromLTRB(1000.0, 80.0, 0.0, 0.0),
                items: <PopupMenuItem<String>>[
                  _buildPopupMenuItem('/import', '本地导入', Icons.save_alt),
                  _buildPopupMenuItem(
                      '/style',
                      '${isListStyle ? "图墙" : "列表"}模式',
                      isListStyle ? Icons.view_module : Icons.view_list),
                ],
              );
              switch (result) {
                case '/import':
                  Navigator.of(context).pushNamed('/importLocal');
                  break;
                case '/style':
                  setState(() {
                    isListStyle = !isListStyle;
                  });
                  break;
              }
            },
          ),
        ],
//        leading: IconButton(
//            icon: Icon(MyIcons.shelfUserIcon),
//            onPressed: () {
//              Navigator.of(context).pushNamed('/acount');
//            }),
//        actions: [
//          IconButton(icon: Icon(MyIcons.shelfManageIcon), onPressed: () {}),
//        ],
      ),
      body: _books.length == 0
          ? Container(
              child: Center(
                child: Text(
                  "空空如也，也是一种态度",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w100,
                    fontSize: 16.0,
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              child: isListStyle
                  ? ListView.separated(
                      itemBuilder: (BuildContext context, int index) {
                        return buildShelfItemView(index);
                      },
                      separatorBuilder: (BuildContext context, int index) {
                        return new Divider(
                          height: 1.0,
                          color: Colors.black12,
                        );
                      },
                      itemCount: _books.length + 1,
                    )
                  : ListView(
                      padding: EdgeInsets.only(top: 0),
                      //controller: scrollController,
                      children: <Widget>[
                        buildShelfItemViewGrid(),
                      ],
                    ),
              onRefresh: _onRefresh,
            ),
    );
  }
}
