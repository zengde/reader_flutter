import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart'
    show required, compute, ValueChanged, VoidCallback;
import 'package:flutter/foundation.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:reader_flutter/bean/book.dart';
import 'package:reader_flutter/bean/volume.dart';
import 'package:reader_flutter/page/reader/reader_page_agent.dart';
import 'package:reader_flutter/util/file_utils.dart';
import 'package:reader_flutter/util/http_manager.dart';

class ReaderEngine {
  static Map<Book, ReaderEngine> _cache;
  final ValueChanged<VoidCallback> _stateSetter;
  final Book _book;
  List<Chapter> mChapterList;
  final int bufferSize = 512 * 1024;
  final int maxLengthWithNoChapter = 10 * 1024;
  RegExp volumeExp = RegExp(
      r'^[\s\t　]*(第?[0-9零一二三四五六七八九十]+卷|卷[0-9零一二三四五六七八九十]+)\s*.{0,20}$',
      unicode: true,
      multiLine: true);
  RegExp chpterExp = RegExp(r'^[\s\t　]*第?[0-9零一二三四五六七八九十序百千]+[章节回话]\s*.{0,20}$',
      unicode: true, multiLine: true);
  RegExp empty = RegExp(r'^[\s　\t]*$');
  File mBookFile;
  Encoding mCharset;
  final ChapterSqlite _chapterSqlite = ChapterSqlite();
  double topSafeHeight;

  factory ReaderEngine(
      {@required Book book,
      @required ValueChanged<VoidCallback> stateSetter,
      double topSafeHeight}) {
//    if (null == _cache) {
    _cache = <Book, ReaderEngine>{};
//    }
    if (!_cache.containsKey(book)) {
      _cache[book] = new ReaderEngine._internal(
          book: book, stateSetter: stateSetter, topSafeHeight: topSafeHeight);
    }
    return _cache[book];
  }

  ReaderEngine._internal(
      {Book book, ValueChanged<VoidCallback> stateSetter, double topSafeHeight})
      : assert(null != book),
        assert(null != stateSetter),
        _book = book,
        _stateSetter = stateSetter,
        topSafeHeight = topSafeHeight {
    mBookFile = new File(_book.path);
    mCharset = _book.charset == 'utf8' ? utf8 : gbk_bytes;
  }

  void refreshChapterList() async {
    if (mChapterList != null) return;
    
    String lastModified =
        new DateFormat('MM/dd/y HH:mm:ss').format(mBookFile.lastModifiedSync());

    // 判断文件是否已经加载过，并具有缓存
    if (_book.updateTime == lastModified) {
      mChapterList = await _chapterSqlite.queryAll(_book.id);
    }
    if (mChapterList != null) return;

    loadChapters();
    _chapterSqlite.insertAll(mChapterList, _book.id);
  }

  void loadChapters() {
    List<Chapter> chapters = [];
    //获取文件流
    RandomAccessFile bookStream = mBookFile.openSync(mode: FileMode.read);
    //寻找匹配文章标题的正则表达式，判断是否存在章节名
    bool hasChapter = true; //checkChapterType(bookStream);
    //加载章节
    List<int> buffer = new List<int>(bufferSize);
    //获取到的块起始点，在文件中的位置
    int curOffset = 0;
    //block的个数
    int blockPos = 0;
    //读取的长度
    int length;
    //分章的位置
    int chapterPos = 0;

    //获取文件中的数据到buffer，直到没有数据为止
    while ((length = bookStream.readIntoSync(buffer, 0, buffer.length)) > 0) {
      ++blockPos;
      //如果存在Chapter
      if (hasChapter) {
        //将数据转换成String
        var tempBuffer = new List<int>(length)..setRange(0, length, buffer);

        String blockContent = mCharset.decode(tempBuffer);

        //当前Block下使过的String的指针
        int seekPos = 0;

        //如果存在相应章节
        if (chpterExp.hasMatch(blockContent)) {
          chpterExp.allMatches(blockContent)
            ..forEach((RegExpMatch matcher) {
              //获取匹配到的字符在字符串中的起始位置
              int chapterStart = matcher.start;

              //如果 seekPos == 0 && nextChapterPos != 0 表示当前block处前面有一段内容
              //第一种情况一定是序章 第二种情况可能是上一个章节的内容
              if (seekPos == 0 && chapterStart != 0) {
                //获取当前章节的内容
                String chapterContent =
                    blockContent.substring(seekPos, chapterStart);
                //设置指针偏移
                seekPos += chapterContent.length;

                //如果当前对整个文件的偏移位置为0的话，那么就是序章
                if (curOffset == 0) {
                  //创建序章
                  Chapter preChapter = new Chapter();
                  preChapter.name = "序章";
                  preChapter.start = 0;
                  preChapter.end = mCharset
                      .encode(chapterContent)
                      .length; //获取String的byte值,作为最终值
                  preChapter.index = chapterPos;

                  //如果序章大小大于30才添加进去
                  if (preChapter.end - preChapter.start > 30) {
                    chapters.add(preChapter);
                    chapterPos++;
                  }

                  //创建当前章节
                  Chapter curChapter = new Chapter();
                  curChapter.name = matcher.group(0).trim();
                  curChapter.start = preChapter.end;
                  curChapter.index = chapterPos;
                  chapters.add(curChapter);
                  chapterPos++;
                }
                //否则就block分割之后，上一个章节的剩余内容
                else {
                  //获取上一章节
                  Chapter lastChapter = chapters.last;
                  //将当前段落添加上一章去
                  lastChapter.end += mCharset.encode(chapterContent).length;

                  //如果章节内容太小，则移除
                  if (lastChapter.end - lastChapter.start < 30) {
                    chapters.remove(lastChapter);
                    chapterPos--;
                  }

                  //创建当前章节
                  Chapter curChapter = new Chapter();
                  curChapter.name = matcher.group(0).trim();
                  curChapter.start = lastChapter.end;
                  curChapter.index = chapterPos;
                  chapters.add(curChapter);
                  chapterPos++;
                }
              } else {
                //是否存在章节
                if (chapters.length != 0) {
                  //获取章节内容
                  String chapterContent =
                      blockContent.substring(seekPos, matcher.start);
                  seekPos += chapterContent.length;

                  //获取上一章节
                  Chapter lastChapter = chapters.last;
                  lastChapter.end = lastChapter.start +
                      mCharset.encode(chapterContent).length;

                  //如果章节内容太小，则移除
                  if (lastChapter.end - lastChapter.start < 30) {
                    chapters.remove(lastChapter);
                    chapterPos--;
                  }

                  //创建当前章节
                  Chapter curChapter = new Chapter();
                  curChapter.name = matcher.group(0).trim();
                  curChapter.start = lastChapter.end;
                  curChapter.index = chapterPos;
                  chapters.add(curChapter);
                  chapterPos++;
                }
                //如果章节不存在则创建章节
                else {
                  Chapter curChapter = new Chapter();
                  curChapter.name = matcher.group(0).trim();
                  curChapter.start = 0;
                  curChapter.index = chapterPos;
                  chapters.add(curChapter);
                  chapterPos++;
                }
              }
            });
        }
      }
      //进行本地虚拟分章
      else {
        //章节在buffer的偏移量
        int chapterOffset = 0;
        //当前剩余可分配的长度
        int strLength = length;

        while (strLength > 0) {
          ++chapterPos;
          //是否长度超过一章
          if (strLength > maxLengthWithNoChapter) {
            //在buffer中一章的终止点
            int end = length;
            //寻找换行符作为终止点
            for (int i = chapterOffset + maxLengthWithNoChapter;
                i < length;
                ++i) {
              if (buffer[i] == ''.codeUnitAt(0)) {
                end = i;
                break;
              }
            }
            Chapter chapter = new Chapter();
            chapter.name = "第" +
                blockPos.toString() +
                "章" +
                "(" +
                chapterPos.toString() +
                ")";
            chapter.start = curOffset + chapterOffset + 1;
            chapter.end = curOffset + end;
            chapter.index = chapterPos - 1;
            chapters.add(chapter);
            //减去已经被分配的长度
            strLength = strLength - (end - chapterOffset);
            //设置偏移的位置
            chapterOffset = end;
          } else {
            Chapter chapter = new Chapter();
            chapter.name = "第" +
                blockPos.toString() +
                "章" +
                "(" +
                chapterPos.toString() +
                ")";
            chapter.start = curOffset + chapterOffset + 1;
            chapter.end = curOffset + length;
            chapter.index = chapterPos - 1;
            chapters.add(chapter);
            strLength = 0;
          }
        }
      }

      //block的偏移点
      curOffset += length;

      if (hasChapter) {
        //设置上一章的结尾
        Chapter lastChapter = chapters.last;
        lastChapter.end = curOffset;
      }

      //当添加的block太多的时候，执行GC
      if (blockPos % 15 == 0) {}
    }

    mChapterList = chapters;
    bookStream.closeSync();
  }

  String getContentWithFile(Chapter chapter) {
    RandomAccessFile bookStream;
    try {
      bookStream = mBookFile.openSync(mode: FileMode.read);
      bookStream.setPositionSync(chapter.start);
      int extent = chapter.end - chapter.start;
      List<int> content = new List<int>(extent);
      bookStream.readIntoSync(content, 0, extent);
      return mCharset.decode(content);
    } catch (e) {
      print(e);
    } finally {
      bookStream.close();
    }

    return '';
  }

  void close() {
    _cache[_book] = null;
    _chapterSqlite.close();
  }

  int get chapterCount {
    return mChapterList.length;
  }

  operator [](int index) {
    if (index < 0 || index > chapterCount - 1) {
      return null;
    }
    var chapter = mChapterList[index];
    if (chapter.pageCount == null) {
      chapter.content = getContentWithFile(chapter);
      chapter.pageOffsets =
          ReaderPageAgent.getPageOffsets(chapter.content, topSafeHeight);
    }
    return chapter;
  }

  ///
  /// unuse
  ///
  Future<List<Chapter>> loadChaptersWithIso() async {
    if (_book.isLocal) {
      var type = getFileType(mBookFile);
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
      mChapterList = await compute(
          func, {'filePath': _book.path, 'charSet': _book.charset});
    } else {
      var map = await getChaptersData(_book.id);
      List<Volume> _volumes = [];
      for (int i = 0; i < map['data']['list'].length; i++) {
        _volumes.add(Volume.fromMap(map['data']['list'][i]));
      }
      for (int i = 0; i < _volumes.length; i++) {
        mChapterList
            .add(Chapter(name: _volumes[i].name, isHeader: true, headerId: i));
        mChapterList.addAll(_volumes[i].list);
      }
    }

    return mChapterList;
  }

  ///
  /// unuse
  ///
  Future<String> getContent(int index) async {
    if (_book.isLocal) {
      return mChapterList[index].content;
    } else {
      var data =
          await getChapterData(_book.id, mChapterList[index].id.toString());
      return data['data']['content'];
    }
  }
}

/// compute有延迟
///
/// _chapters = await compute(decodeText, {'filePath': widget.filePath, 'charSet': _book.charset});
///
/// _chapters = decodeText({'filePath': widget.filePath, 'charSet': _book.charset});
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
