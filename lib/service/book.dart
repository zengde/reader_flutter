import 'dart:io';
import 'dart:async';
import 'package:reader_flutter/bean/book.dart';
import 'package:reader_flutter/util/file_utils.dart';

import 'system.dart';

class BookService {
  static BookService _cache;

  factory BookService() {
    if (null == _cache) {
      _cache = new BookService._internal();
    }
    return _cache;
  }

  BookService._internal();

  SystemService service = new SystemService();

  FutureOr<int> importLocalBooks(List<FileSystemEntity> list,BookSqlite db) async {
    if (null == list || list.isEmpty) {
      return 0;
    }
    List<Book> books = <Book>[];
    list.forEach((FileSystemEntity file) {
      if (!fileIsBook(file)) return 0;
      Book b=Book.fromFile(file);
      books.add(b);
      db.insert(b);
    });
    return books.length;
  }
}
