import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'
    show required, compute, ValueChanged, VoidCallback;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:reader_flutter/bean/book.dart';
import 'package:reader_flutter/bean/volume.dart';
import 'package:reader_flutter/page/reader/reader_page_agent.dart';
import 'package:reader_flutter/util/file_utils.dart';
import 'package:reader_flutter/util/http_manager.dart';
import 'package:crypto/crypto.dart' show md5;

class ReaderEngine {
  static Map<Book, ReaderEngine> _cache;
  final ValueChanged<VoidCallback> _stateSetter;
  final Book _book;
  List<Chapter> mChapterList;

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
    mCharset =
        _book.charset == 'utf8' ? Utf8Codec(allowMalformed: true) : gbk_bytes;
  }

  refreshChapterList() async {
    if (mChapterList != null) return;

    String lastModified =
        new DateFormat('MM/dd/y HH:mm:ss').format(mBookFile.lastModifiedSync());

    // 判断文件是否已经加载过，并具有缓存
    String fileMd5 = '';
    if (_book.updateTime == lastModified) {
      fileMd5 = md5.convert(_book.path.codeUnits).toString();
      mChapterList = await _chapterSqlite.queryAllByHash(fileMd5);
    }
    if (mChapterList != null) return;
    //mChapterList =
    //await compute(decodeText4, {'file': mBookFile, 'charset': mCharset});
    mChapterList = await decodeText4({'file': mBookFile, 'charset': mCharset});
    _chapterSqlite.insertAllWithHash(mChapterList, _book.id, fileMd5);
  }

  String getContentWithFile(Chapter chapter) {
    RandomAccessFile bookStream;
    try {
      bookStream = mBookFile.openSync(mode: FileMode.read);
      bookStream.setPositionSync(chapter.start);
      int extent = chapter.end - chapter.start;
      List<int> contentBuffer = new List<int>(extent);
      bookStream.readIntoSync(contentBuffer, 0, extent);
      return mCharset.decode(contentBuffer).replaceAll(emptyExp, '');
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
      if (chapter.content == '' && chapter.end != 0) {
        chapter.content = getContentWithFile(chapter);
      }

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

final int bufferSize = 512 * 1024;
final int maxLengthWithNoChapter = 10 * 1024;
final RegExp volumeExp = RegExp(
    r'^[\s\t　]*(第?[0-9零一二三四五六七八九十]+卷|卷[0-9零一二三四五六七八九十]+)\s*.{0,20}$',
    unicode: true,
    multiLine: true);
final RegExp chapterExp = RegExp(
    r'^[\s\t　]*第?[0-9零一二两三四五六七八九十序百千]+[章节回话]\s*.{0,20}$',
    unicode: true,
    multiLine: true);
final RegExp emptyExp = RegExp(r'^[\s　\t]*$', unicode: true, multiLine: true);

bool checkChapterType(RandomAccessFile bookStream, Encoding mCharset) {
  //首先获取128k的数据
  List<int> buffer = new List<int>(bufferSize ~/ 4);
  int length = bookStream.readIntoSync(buffer, 0, buffer.length);
  var tempBuffer = new List<int>(length)..setRange(0, length, buffer);
  String blockContent = mCharset.decode(tempBuffer);
  //进行章节匹配
  if (chapterExp.hasMatch(blockContent)) {
    bookStream.setPositionSync(0);
    return true;
  }

  //重置指针位置
  bookStream.setPositionSync(0);
  return false;
}

/// by lines
///
/// _chapters = await compute(decodeText, {'file': File, 'charset': Encoding});
List<Chapter> decodeText(Map<String, dynamic> param) {
  List<Chapter> chapters = [];
  Encoding mCharset = param['charset'];
  File mBookFile = param['file'];

  int k = -1;
  bool iscn = false;
  String _full = '';

  List lines = mBookFile.readAsLinesSync(encoding: mCharset);
  lines.forEach((line) {
    print(line);
    if (emptyExp.hasMatch(line)) {
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
            'headerId': k,
            'index': k
          }));
      iscn = false;
    } else if (chapterExp.hasMatch(line)) {
      k++;
      Iterable<RegExpMatch> chapterMatches = chapterExp.allMatches(line);
      chapters.insert(
          k,
          Chapter.fromMap({
            'name': chapterMatches.elementAt(0).group(0),
            'isHeader': false,
            'id': k,
            'index': k
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
  return chapters;
}

/// by stream
List<Chapter> decodeText2(Map<String, dynamic> param) {
  List<Chapter> chapters = [];
  Encoding mCharset = param['charset'];
  File mBookFile = param['file'];
  try {
    int k = -1;
    bool iscn = false;
    String _full = '';

    Stream<List<int>> inputStream = mBookFile.openRead();

    Utf8Codec _utf8 = Utf8Codec(allowMalformed: true);
    inputStream
        .map((List<int> input) {
          return mCharset.name == 'utf-8'
              ? input
              : utf8.encode(mCharset.decode(input));
        })
        .transform(_utf8.decoder) // Decode bytes to UTF-8. gbk.decoder
        .transform(new LineSplitter()) // Convert stream to individual lines.
        .listen((String line) {
          if (emptyExp.hasMatch(line)) {
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
                  'headerId': k,
                  'index': k
                }));
            iscn = false;
          } else if (chapterExp.hasMatch(line)) {
            k++;
            Iterable<RegExpMatch> chapterMatches = chapterExp.allMatches(line);
            chapters.insert(
                k,
                Chapter.fromMap({
                  'name': chapterMatches.elementAt(0).group(0),
                  'isHeader': false,
                  'id': k,
                  'index': k
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
  return chapters;
}

/// by block
List<Chapter> decodeText3(Map<String, dynamic> param) {
  Encoding mCharset = param['charset'];
  File mBookFile = param['file'];

  List<Chapter> chapters = [];
  //获取文件流
  RandomAccessFile bookStream = mBookFile.openSync(mode: FileMode.read);
  //寻找匹配文章标题的正则表达式，判断是否存在章节名
  bool hasChapter = checkChapterType(bookStream, mCharset);
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
      if (chapterExp.hasMatch(blockContent)) {
        chapterExp.allMatches(blockContent)
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
                if (chapters.length != 0) {
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
                lastChapter.end =
                    lastChapter.start + mCharset.encode(chapterContent).length;

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

    if (hasChapter && chapters.length != 0) {
      //设置上一章的结尾
      Chapter lastChapter = chapters.last;
      lastChapter.end = curOffset;
    }

    //当添加的block太多的时候，执行GC
    if (blockPos % 15 == 0) {}
  }

  bookStream.closeSync();
  return chapters;
}

/// by all
Future<List<Chapter>> decodeText4(Map<String, dynamic> param) async {
  /// gbk直接调用变韩文
  Encoding mCharset = param['charset'].name == 'utf-8' ? utf8 : gbk_bytes;
  File mBookFile = param['file'];

  //String content = mBookFile.readAsStringSync(encoding: mCharset);
  String content = await readFile(mBookFile, mCharset);

  List<Chapter> chapters = [];
  List<Chapter> volumns = [];
  Iterable<RegExpMatch> volumeMatches = volumeExp.allMatches(content);

  if (volumeMatches.length > 0) {
    int offset = 0;
    if (volumeMatches.first.start > 150) {
      var fcontent = content.substring(0, volumeMatches.first.start);
      volumns.insert(
          0,
          Chapter.fromMap({
            'isHeader': false,
            'name': '正文卷',
            'content': fcontent,
            'start': 0
          }));
      offset = 1;
    }

    int i = 0;
    for (; i < volumeMatches.length; i++) {
      var r = volumeMatches.elementAt(i);
      var index = i + offset;
      volumns.insert(
          index,
          Chapter.fromMap({
            'name': r.group(0).trim(),
            'content': '',
            'start': r.start,
            'end': r.end,
            'isHeader': 0
          }));
      if (i > 0) {
        int start = volumns[index - 1].end;
        int end = volumns[index].start;
        volumns[index - 1].content = content.substring(start, end);
      }
    }
    volumns[i + offset].content = content.substring(volumns[i + offset].end);
  } else {
    volumns.add(Chapter.fromMap(
        {'name': '正文卷', 'content': content, 'start': 0, 'isHeader': 1}));
  }

  int k = 0;
  volumns.forEach((Chapter volumn) {
    String volumnContent = volumn.content;
    Iterable<RegExpMatch> chapterMatches = chapterExp.allMatches(volumnContent);
    if (chapterMatches.length > 0) {
      int i = 0;
      for (; i < chapterMatches.length; i++) {
        var r = chapterMatches.elementAt(i);
        if (i == 0 && r.start > 150) {
          chapters.insert(
              k,
              Chapter.fromMap({
                'name': '序章',
                'isHeader': false,
                'index': k,
                'content': volumnContent.substring(0, r.start),
              }));
          k++;
        }

        chapters.insert(
            k,
            Chapter.fromMap({
              'name': r.group(0).trim(),
              'isHeader': false,
              'index': k,
              'content': '',
              'start': r.start,
              'end': r.end
            }));

        if (i > 0) {
          int start = chapters[k - 1].end;
          int end = chapters[k].start;
          chapters[k - 1].content = volumnContent.substring(start, end);
        }
        k++;
      }
      chapters[k - 1].content = volumnContent.substring(chapters[k - 1].end);
    } else {
      chapters.insert(
        k,
        Chapter.fromMap({
          'name': volumn.isHeader ? '全文' : '全卷',
          'isHeader': false,
          'index': k,
          'content': volumnContent
        }),
      );
      k++;
    }
  });
  return chapters;
}

/// gbk_bytes 解码太慢
Future<String> readFile(File file, Encoding charset) async {
  if (charset.name == 'utf-8') {
    return file.readAsStringSync();
  }

  String result = '';
  if (Platform.isAndroid) {
    String path = file.path;
    final platform = const MethodChannel('zengde.github.com/file');

    Map<String, String> param = {'path': path, 'charset': 'gbk'};
    result = await platform.invokeMethod('readFile', param);

    platform.setMethodCallHandler((call) {
      int message = call.arguments;
      String method = call.method;
      if (method == 'finishFile') {}

      print(message);
    });
  } else {
    List<int> bytes = file.readAsBytesSync();
    result = await compute(gbk_bytes.decode, bytes);
  }

  return result;
}

List<Chapter> decodeEpub(Map<String, dynamic> param) {
  return null;
}

List<Chapter> decodePdf(Map<String, dynamic> param) {
  return null;
}
