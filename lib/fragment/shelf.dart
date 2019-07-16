import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reader_flutter/bean/book.dart';
import 'package:reader_flutter/bean/info.dart';
import 'package:reader_flutter/page/read.dart';
import 'package:reader_flutter/page/read_local.dart';
import 'package:reader_flutter/util/constants.dart';
import 'package:reader_flutter/util/http_manager.dart';
import 'package:file_picker/file_picker.dart';

class BookShelf extends StatefulWidget {
  @override
  _BookShelfState createState() => _BookShelfState();
}

class _BookShelfState extends State<BookShelf>
    with AutomaticKeepAliveClientMixin {
  List<Book> _books = [];
  final BookSqlite bookSqlite = BookSqlite();

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

  Widget bookShelfItem(Book book) {
    return InkWell(
      onLongPress: () {
        showAlertDialog(book);
      },
      onTap: () {
        Navigator.push(context,
            MaterialPageRoute(builder: (BuildContext context) {
          return book.isLocal ? ReadPage(book.id) : ReadPageLocal(book.path);
        }));
      },
      highlightColor: Colors.black12,
      child: Container(
        margin: EdgeInsets.only(left: 15, right: 15, top: 10, bottom: 10),
        height: 100.0,
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(2.0),
              child: book.isLocal
                  ? Image.asset(
                      'images/cover_txt.png',
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
          ],
        ),
      ),
    );
  }

  void showAlertDialog(Book book) {
    showDialog(
        context: context,
        builder: (_) => new AlertDialog(
                title: new Text("提示"),
                content: new Column(
                  children: <Widget>[
                    new Text("是否删除 ${book.name}?"),
                    book.isLocal? CheckboxListTile(
                      title:Text("是否同时删除本地文件?") ,
                      value: true,
                      onChanged: (val){},
                    ):Container(),
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

  PopupMenuItem<String> _buildPopupMenuItem(String path, String text) {
    return new PopupMenuItem<String>(
      value: path,
      child: Row(children: <Widget>[
        Padding(
            padding: EdgeInsets.fromLTRB(0.0, 0.0, 8.0, 0.0),
            child: Icon(Icons.add)),
        Text(text)
      ]),
    );
  }

  void getFilePath() async {
    try {
      String filePath = await FilePicker.getFilePath(
          type: FileType.CUSTOM, fileExtension: 'txt');
      if (filePath == '') {
        return;
      }
      print(filePath);
      Navigator.push(context,
          MaterialPageRoute(builder: (BuildContext context) {
        return ReadPageLocal(filePath);
      }));
    } on PlatformException catch (e) {
      print("Error while picking file");
    }
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
            icon: Icon(Icons.list),
            onPressed: () async {
              final result = await showMenu(
                context: context,
                position: RelativeRect.fromLTRB(1000.0, 80.0, 0.0, 0.0),
                items: <PopupMenuItem<String>>[
                  _buildPopupMenuItem('/import', '导入图书'),
                ],
              );
              switch (result) {
                case '/import':
                  getFilePath();
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
              child: ListView.separated(
                itemBuilder: (BuildContext context, int index) {
                  return bookShelfItem(_books[index]);
                },
                separatorBuilder: (BuildContext context, int index) {
                  return new Divider(
                    height: 1.0,
                    color: Colors.black12,
                  );
                },
                itemCount: _books.length,
              ),
              onRefresh: _onRefresh,
            ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
