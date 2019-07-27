import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart'
    show required, compute, ValueChanged, VoidCallback;
import 'package:gbk_codec/gbk_codec.dart';
import 'package:reader_flutter/bean/book.dart';
import 'package:reader_flutter/bean/volume.dart';
import 'package:reader_flutter/util/file_utils.dart';
import 'package:reader_flutter/util/http_manager.dart';

class ReaderEngine {
  static Map<Book, ReaderEngine> _cache;
  final ValueChanged<VoidCallback> _stateSetter;
  final Book _book;
  List<Chapter> chapters;

  factory ReaderEngine(
      {@required Book book, @required ValueChanged<VoidCallback> stateSetter}) {
//    if (null == _cache) {
    _cache = <Book, ReaderEngine>{};
//    }
    if (!_cache.containsKey(book)) {
      _cache[book] =
          new ReaderEngine._internal(book: book, stateSetter: stateSetter);
    }
    return _cache[book];
  }

  ReaderEngine._internal({Book book, ValueChanged<VoidCallback> stateSetter})
      : assert(null != book),
        assert(null != stateSetter),
        _book = book,
        _stateSetter = stateSetter;

  Future<List<Chapter>> getChapters() async {
    if (_book.isLocal) {
      var type = getFileType(new File(_book.path));
      var func;
      switch (type) {
        case FileType.TEXT:
          func = decodeText;
          break;
        case FileType.EPUB:
        case FileType.PDF:
        default:
          throw new Exception('暂时不支持此格式！');
          break;
      }
      chapters = await compute(
          func, {'filePath': _book.path, 'charSet': _book.charset});
    } else {
      var map = await getChaptersData(_book.id);
      List<Volume> _volumes = [];
      for (int i = 0; i < map['data']['list'].length; i++) {
        _volumes.add(Volume.fromMap(map['data']['list'][i]));
      }
      for (int i = 0; i < _volumes.length; i++) {
        chapters
            .add(Chapter(name: _volumes[i].name, isHeader: true, headerId: i));
        chapters.addAll(_volumes[i].list);
      }
    }

    return chapters;
  }

  Future<String> getContent(int index) async {
    if (_book.isLocal) {
      return chapters[index].content;
    } else {
      var data = await getChapterData(_book.id, chapters[index].id.toString());
      return data['data']['content'];
    }
  }
}

List<Chapter> decodeText(Map<String, String> param) {
  print('startdecode' + DateTime.now().toString());
  List<Chapter> chapters = [];
  String filePath = param['filePath'];
  String charset = param['charSet'];

  RegExp volumeExp = RegExp(
      r'^[\s\t　]*(第?[0-9零一二三四五六七八九十]+卷|卷[0-9零一二三四五六七八九十]+)\s*.{0,20}$',
      unicode: true);
  RegExp chpterExp = RegExp(r'^[\s\t　]*第?[0-9零一二三四五六七八九十序百千]+[章节回话]\s*.{0,20}$',
      unicode: true);
  RegExp empty = RegExp(r'^[\s　\t]*$');

  int k = -1;
  bool iscn = false;
  String _full = '';

  final file = new File('$filePath');
  var encoding = charset == 'utf8' ? utf8 : gbk_bytes;
  print('startfile' + DateTime.now().toString());
  List lines = file.readAsLinesSync(encoding: encoding);
  print('endfile' + DateTime.now().toString() + lines.length.toString());
  lines.forEach((line) {
    if (line == '') {
      return;
    }
    if (volumeExp.hasMatch(line)) {
      k++;
      Iterable<RegExpMatch> volumeMatches = volumeExp.allMatches(line);
      chapters.insert(
          k,
          Chapter.fromMap({
            'name': volumeMatches.elementAt(0).group(0),
            'isHeader': true,
            'id': k,
            'headerId': k
          }));
      iscn = false;
    } else if (chpterExp.hasMatch(line)) {
      k++;
      Iterable<RegExpMatch> chapterMatches = chpterExp.allMatches(line);
      chapters.insert(
          k,
          Chapter.fromMap({
            'name': chapterMatches.elementAt(0).group(0),
            'isHeader': false,
            'id': k
          }));
      iscn = true;
    } else {
      if (iscn) {
        chapters[k].content = chapters[k].content + line + "\r\n";
      }
    }
    _full += line + "\r\n";
  });
  if (chapters.length < 1) {
    chapters.insert(0, new Chapter(name: '全文', isHeader: false));
    chapters[0].content = _full;
  }
  print('endfor' + DateTime.now().toString());
  return chapters;
}

List<Chapter> decodeText2(Map<String, String> param) {
  /*
    String fileMd5 = md5.convert(filePath.codeUnits).toString() + '.json';
    Directory appDirectory = await getApplicationDocumentsDirectory();
    File chapterFile = new File(p.join(appDirectory.path, fileMd5));
    if (chapterFile.existsSync()) {
      var responseStr = chapterFile.readAsStringSync();
      var responseJson = json.decode(responseStr);
      return responseJson['chapters'];
    }
    */
  List<Chapter> chapters = [];
  String filePath = param['filePath'];
  String charset = param['charSet'];
  try {
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
    file.readAsLinesSync();
    Stream<List<int>> inputStream = file.openRead();

    Utf8Codec _utf8 = Utf8Codec(allowMalformed: true);
    inputStream
        .map((List<int> input) {
          return charset == 'utf8'
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
            chapters.insert(
                k,
                Chapter.fromMap({
                  'name': volumeMatches.elementAt(0).group(0),
                  'isHeader': true,
                  'id': k,
                  'headerId': k
                }));
            iscn = false;
          } else if (chpterExp.hasMatch(line)) {
            k++;
            Iterable<RegExpMatch> chapterMatches = chpterExp.allMatches(line);
            chapters.insert(
                k,
                Chapter.fromMap({
                  'name': chapterMatches.elementAt(0).group(0),
                  'isHeader': false,
                  'id': k
                }));
            iscn = true;
          } else {
            if (iscn) {
              chapters[k].content = chapters[k].content + line + "\r\n";
            }
          }
          //_full += line + "\r\n";
        }, onDone: () {
          if (chapters.length < 1) {
            chapters.insert(0, new Chapter(name: '全文', isHeader: false));
            chapters[0].content = _full;
          }
          print('File is now closed.');
        }, onError: (e) {
          print(e.toString());
        });
  } catch (err) {
    print(err);
  }
}

List<Chapter> decodeEpub(Map<String, String> param) {
  return null;
}

List<Chapter> decodePdf(Map<String, String> param) {
  return null;
}
