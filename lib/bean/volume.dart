/// name : "作品相关"
/// list : [{"id":4785213,"name":"新书即将开始了","hasContent":0},{"id":4785214,"name":"上架了,求订阅,求月票!","hasContent":0},null]
import 'package:adsorptionview_flutter/adsorptiondatabin.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

final String tableBook = 'chapter';
final String columnId = 'id';
final String columnName = 'name';
final String columnHasContent = 'hasContent';
final String columnIsHeader = 'isHeader';
final String columnHeaderId = 'headerId';
final String columnContent = 'content';
final String columnStart = 'start';
final String columnEnd = 'end';
final String columnIndex = 'orderss';
final String columnBookId = 'bookid';
final String columnBookHash = 'md5';

class Volume {
  String name;
  List<Chapter> list;

  static Volume fromMap(Map<String, dynamic> map) {
    if (map == null) return null;
    Volume volumeBean = Volume();
    volumeBean.name = map['name'];
    volumeBean.list = List()
      ..addAll((map['list'] as List ?? []).map((o) => Chapter.fromMap(o)));
    return volumeBean;
  }
}

/// id : 4785213
/// name : "新书即将开始了"
/// hasContent : 0

class Chapter extends AdsorptionData {
  int id;
  String name;
  int hasContent;
  bool isHeader;
  int headerId;
  String content = '';
  List<Map<String, int>> pageOffsets;
  int start;
  int end;
  int index;
  int bookid;
  String bookhash;

  Chapter({this.name, this.isHeader = false, this.headerId});

  static Chapter fromMap(Map<String, dynamic> map) {
    if (map == null) return null;
    Chapter listBean = Chapter();
    listBean.id = map['id'];
    listBean.name = map['name'];
    listBean.hasContent = map['hasContent'];
    listBean.isHeader = map['isHeader'] == null ? false : map['isHeader'] == 1;
    listBean.headerId = map['headerId'] ?? -1;
    listBean.index = map[columnIndex] ?? 0;
    listBean.start = map['start'] ?? 0;
    listBean.end = map['end'] ?? 0;
    listBean.content = map['content'] ?? '';
    listBean.bookid = map['bookid'] ?? 0;
    listBean.bookhash = map['bookhash'] ?? '';
    return listBean;
  }

  String stringAtPageIndex(int index) {
    var offset = pageOffsets[index];
    return this.content.substring(offset['start'], offset['end']);
  }

  int get pageCount {
    return pageOffsets?.length;
  }

  int get preId {
    return index - 1;
  }

  int get nextId {
    return index + 1;
  }

  int get fakeid {
    return 1000000 + index;
  }

  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{
      columnName: name,
      columnHasContent: hasContent,
      columnIsHeader: isHeader ? 1 : 0,
      columnHeaderId: headerId,
      columnContent: content,
      columnStart: start,
      columnEnd: end,
      columnIndex: index,
      columnBookId: bookid,
      columnBookHash: bookhash
    };
    if (id != null) {
      map[columnId] = id;
    }
    return map;
  }
}

class ChapterSqlite {
  Database db;

  openSqlite() async {
    // 获取数据库文件的存储路径
    var databasesPath = await getDatabasesPath();
    String path = join(databasesPath, 'chapter.db');

//根据数据库文件路径和数据库版本号创建数据库表
    db = await openDatabase(path, version: 6,
        onCreate: (Database db, int version) async {
      await db.execute('''
          CREATE TABLE $tableBook (
            $columnId INTEGER PRIMARY KEY, 
            $columnName TEXT, 
            $columnHasContent INTEGER, 
            $columnIsHeader INTEGER, 
            $columnHeaderId INTEGER,
            $columnContent TEXT, 
            $columnStart INTEGER, 
            $columnEnd INTEGER,
            $columnIndex INTEGER,
            $columnBookId INTEGER,
            $columnBookHash TEXT)
          ''');
    }, onUpgrade: (Database db, int oldVersion, int newVersion) async {
      if (oldVersion == 4)
        await db.execute("ALTER TABLE $tableBook ADD $columnBookId INTEGER");
      if (oldVersion == 5)
        await db.execute("ALTER TABLE $tableBook ADD $columnBookHash TEXT");
    });
  }

  Future<int> insert(Chapter chapter) async {
    await this.openSqlite();
    return await db.insert(tableBook, chapter.toMap());
  }

  Future<int> insertAll(List<Chapter> chapters, int bookid) async {
    await this.openSqlite();
    Batch batch = db.batch();
    Map<int, Chapter> map = chapters.asMap();
    map.forEach((index, chapter) {
      chapter.bookid = bookid;
      chapter.index = index;
      batch.insert(tableBook, chapter.toMap());
    });
    var results = await batch.commit();
    return results.length;
  }

  Future<int> insertAllWithHash(
      List<Chapter> chapters, int bookid, String md5) async {
    await this.openSqlite();
    Batch batch = db.batch();
    Map<int, Chapter> map = chapters.asMap();
    map.forEach((index, chapter) {
      chapter.bookid = bookid;
      chapter.bookhash = md5;
      chapter.index = index;
      batch.insert(tableBook, chapter.toMap());
    });
    var results = await batch.commit();
    return results.length;
  }

  Future<List<Chapter>> queryAll(int bookid) async {
    await this.openSqlite();
    List<Map> maps = await db.query(tableBook,
        columns: [
          columnId,
          columnName,
          columnHasContent,
          columnIsHeader,
          columnHeaderId,
          columnContent,
          columnStart,
          columnEnd,
          columnIndex,
          columnBookId
        ],
        where: '$columnBookId = ?',
        whereArgs: [bookid]);

    if (maps == null || maps.length == 0) {
      return null;
    }

    List<Chapter> books = [];
    for (int i = 0; i < maps.length; i++) {
      books.add(Chapter.fromMap(maps[i]));
    }
    return books;
  }

  Future<List<Chapter>> queryAllByHash(String md5) async {
    await this.openSqlite();
    List<Map> maps = await db.query(tableBook,
        columns: [
          columnId,
          columnName,
          columnHasContent,
          columnIsHeader,
          columnHeaderId,
          columnContent,
          columnStart,
          columnEnd,
          columnIndex,
          columnBookId
        ],
        where: '$columnBookHash = ?',
        whereArgs: [md5]);

    if (maps == null || maps.length == 0) {
      return null;
    }

    List<Chapter> books = [];
    for (int i = 0; i < maps.length; i++) {
      books.add(Chapter.fromMap(maps[i]));
    }
    return books;
  }

  Future<Chapter> getChapter(int id) async {
    await this.openSqlite();
    List<Map> maps = await db.query(tableBook,
        columns: [
          columnId,
          columnName,
          columnHasContent,
          columnIsHeader,
          columnHeaderId,
          columnContent,
          columnStart,
          columnEnd,
          columnIndex
        ],
        where: '$columnId = ?',
        whereArgs: [id]);
    if (maps.length > 0) {
      return Chapter.fromMap(maps.first);
    }
    return null;
  }

  /// 根据ID删除章节信息
  Future<int> delete(int id) async {
    await this.openSqlite();
    return await db.delete(tableBook, where: '$columnId = ?', whereArgs: [id]);
  }

  /// 根据书籍ID删除章节信息
  Future<int> deleteByBook(int bookid) async {
    await this.openSqlite();
    return await db
        .delete(tableBook, where: '$columnBookId = ?', whereArgs: [bookid]);
  }

  // 更新书籍信息
  Future<int> update(Chapter book) async {
    await this.openSqlite();
    print("更新${book.toMap()}");
    return await db.update(tableBook, book.toMap(),
        where: '$columnId = ?', whereArgs: [book.id]);
  }

  // 记得及时关闭数据库，防止内存泄漏
  close() async {
    await db?.close();
  }
}
