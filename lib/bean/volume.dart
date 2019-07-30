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

  Chapter({this.name, this.isHeader = false, this.headerId});

  static Chapter fromMap(Map<String, dynamic> map) {
    if (map == null) return null;
    Chapter listBean = Chapter();
    listBean.id = map['id'];
    listBean.name = map['name'];
    listBean.hasContent = map['hasContent'];
    listBean.isHeader = map['isHeader'] == null ? false : map['isHeader'] == 1;
    listBean.headerId = map['headerId'] ?? -1;
    listBean.index = map['index'] ?? 0;
    listBean.start = map['start'] ?? 0;
    listBean.end = map['end'] ?? 0;
    listBean.content = map['content'] ?? '';
    return listBean;
  }

  String stringAtPageIndex(int index) {
    var offset = pageOffsets[index];
    return this.content.substring(offset['start'], offset['end']);
  }

  int get pageCount {
    return pageOffsets?.length;
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
      columnIndex: index
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
    db = await openDatabase(path, version: 4,
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
            $columnIndex INTEGER)
          ''');
    });
  }

  Future<int> insert(Chapter chapter) async {
    await this.openSqlite();
    return await db.insert(tableBook, chapter.toMap());
  }

  Future<int> insertAll(List<Chapter> chapters) async {
    await this.openSqlite();
    Batch batch = db.batch();
    chapters.forEach((chapter) {
      batch.insert(tableBook, chapter.toMap());
    });
    var results = await batch.commit();
    return results.length;
  }

  Future<List<Chapter>> queryAll() async {
    await this.openSqlite();
    List<Map> maps = await db.query(tableBook, columns: [
      columnId,
      columnName,
      columnHasContent,
      columnIsHeader,
      columnHeaderId,
      columnContent,
      columnStart,
      columnEnd,
      columnIndex
    ]);

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

  // 根据ID删除书籍信息
  Future<int> delete(int id) async {
    await this.openSqlite();
    return await db.delete(tableBook, where: '$columnId = ?', whereArgs: [id]);
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
