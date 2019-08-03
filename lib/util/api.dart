/// 追书神器api
/// https://github.com/xiadd/zhuishushenqi/tree/next/src/api
/// https://github.com/amumu233/zhuishushenqi/wiki/API-%E6%8E%A5%E5%8F%A3%E6%96%87%E6%A1%A3
class Zssq {
  /// API域名
  static const baseUrl='http://api.zhuishushenqi.com';
  /// 图片域名
  static const staticUrl='http://statics.zhuishushenqi.com';
  /// 章节域名
  static const chapterUrl='http://chapter2.zhuishushenqi.com';

  /// 带书籍数量的父分类
  static const category = '/cats/lv2/statistics';
  
  /// 带子分类的父分类
  static const subCategory = '/cats/lv2';
  
  /// 获取分类书籍
  /// 
  /// gender:(male|female),type:(hot|new|reputation|over),major:父分类,minor:子分类,start,limit
  static const categoryList = '/book/by-categories';
  
  /// 书籍详情
  static const detail = '/book/:id';
  
  /// 相关推荐
  static const recommend = '/book/:id/recommend';
  
  /// 书籍章节
  //static const chapters = '/btoc';
  static const chapters = '/mix-atoc/{bookid}?view=chapters';
  
  /// 书源
  static const source = '/atoc';
  
  /// 章节内容
  static const chapter = '/chapter/:chapterLink';
  
  /// 作者的书籍
  static const authorBooks = '/book/accurate-search?author=:author';
  
  /// 排名分类
  static const rankingCategory = '/ranking/gender';
  
  /// 排名详情
  static const rankingList = '/ranking/:id';
  
  /// 书评-讨论
  /// 
  /// book: {bookId},sort: (updated|created|comment-count),start,limit,type: (normal,vote)
  static const commentTalk = '/post/by-book?&start=21&limit=20';
  
  /// 书评-短评
  /// 
  /// book: {bookId},sortType: (lastUpdated|newest|mostlike),start,limit
  static const commentShort = '/post/short-review/by-book';
  
  /// 书评--长评
  /// 
  /// book: {bookId},sort: (updated|created|comment-count),start,limit
  static const comment = '/post/review/by-book?book=:bookId&sort=updated&start=0&limit=20';
  
  /// 书单
  /// 
  /// sort,duration,gender,tag,start
  /// 
  /// 本周最热的query是: sort=collectorCount&duration=last-seven-days&start=0
  /// 
  /// 最新发布是: sort=created&duration=all
  /// 
  /// 最多收藏是: sort=collectorCount&duration=all
  static const collection = '/book-list';
  
  /// 书单详情
  static const collectionDetail = '/book-list/:bookId';
  
  /// 搜索热词
  static const searchhot = '/book/search-hotwords';
  
  /// 书籍搜索 可以搜索作者但是不精确
  static const search = '/book/fuzzy-search';
  
  /// 热门搜索
  static const hotwords = '/book/hot-word';
  
  /// 搜索补全
  static const suggest = '/book/auto-complete?query={keyword}';
}
