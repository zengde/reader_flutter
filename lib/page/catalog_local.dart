import 'package:adsorptionview_flutter/adsorptionview_flutter.dart';
import 'package:flutter/material.dart';
import 'package:reader_flutter/bean/volume.dart';
import 'package:reader_flutter/fragment/book_mark.dart';
import 'package:reader_flutter/fragment/chapter.dart';
import 'package:reader_flutter/page/read_local.dart';

class CatalogPageLocal extends StatefulWidget {
  @override
  _CatalogPageLocalState createState() => _CatalogPageLocalState();

  final String bookPath;
  final List<Chapter> _chapters;

  final callBack1;

  final callBack2;

  CatalogPageLocal(this.bookPath, this._chapters,
      {this.callBack1, this.callBack2});
}

class _CatalogPageLocalState extends State<CatalogPageLocal>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  TabController _tabController;

  List<String> _tabTitles = ["目录", "书签"];

  @override
  void initState() {
    _tabController = TabController(length: _tabTitles.length, vsync: this);
    super.initState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void change(Chapter chapter) {
    if (widget.callBack1 != null) {
      widget.callBack1(chapter);
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (BuildContext context) {
        return ReadPageLocal(
          widget.bookPath,
          chapter: chapter,
        );
      }));
    }
  }

  Widget _chapterText(Chapter chapter) {
    return InkWell(
      onTap: () {
        change(chapter);
      },
      child: Container(
        padding: EdgeInsets.only(left: 20),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            chapter.name.trim(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        brightness: Brightness.light,
        iconTheme: IconThemeData(color: Colors.grey),
        centerTitle: true,
//        actions: <Widget>[
//          IconButton(icon: Icon(Icons.import_export), onPressed: () {})
//        ],
        title: Container(
          width: 150,
          child: TabBar(
            indicatorSize: TabBarIndicatorSize.label,
            indicatorColor: Colors.redAccent,
            labelColor: Colors.redAccent,
            unselectedLabelColor: Colors.black54,
            controller: _tabController,
            tabs: _tabTitles.map((title) {
              return Tab(text: title);
            }).toList(),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          AdsorptionView(
            itemHeight: 60,
            adsorptionDatas: widget._chapters,
            generalItemChild: (Chapter chapter) {
              return _chapterText(chapter);
            },
            headChild: (Chapter chapter) {
              return Text('正文');
            },
          ),
          AdsorptionView(
            itemHeight: 60,
            adsorptionDatas: widget._chapters,
            generalItemChild: (Chapter chapter) {
              return _chapterText(chapter);
            },
            headChild: (Chapter chapter) {
              return Text('正文');
            },
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
