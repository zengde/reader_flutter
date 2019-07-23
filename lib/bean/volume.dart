/// name : "作品相关"
/// list : [{"id":4785213,"name":"新书即将开始了","hasContent":0},{"id":4785214,"name":"上架了,求订阅,求月票!","hasContent":0},null]
import 'package:adsorptionview_flutter/adsorptiondatabin.dart';

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

  Chapter({this.name, this.isHeader, this.headerId});

  static Chapter fromMap(Map<String, dynamic> map) {
    if (map == null) return null;
    Chapter listBean = Chapter();
    listBean.id = map['id'];
    listBean.name = map['name'];
    listBean.hasContent = map['hasContent'];
    listBean.isHeader = false;
    listBean.headerId = -1;
    listBean.index = map['index'] ?? 0;
    return listBean;
  }

  String stringAtPageIndex(int index) {
    var offset = pageOffsets[index];
    return this.content.substring(offset['start'], offset['end']);
  }

  int get pageCount {
    return pageOffsets?.length;
  }
}
