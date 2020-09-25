import 'dart:collection';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_novel/app/html_parser/parser.dart';
import 'package:flutter_novel/app/novel/entity/entity_novel_info.dart';
import 'package:flutter_novel/app/novel/model/zssq/model_book_db.dart';

import 'package:flutter/material.dart';
import 'package:flutter_novel/app/novel/entity/entity_novel_book_chapter.dart';
import 'package:flutter_novel/app/novel/model/model_novel_cache.dart';
import 'package:flutter_novel/app/novel/model/zssq/model_book_net.dart';
import 'package:flutter_novel/app/novel/widget/reader/content/helper/helper_reader_content.dart';
import 'package:flutter_novel/app/novel/widget/reader/manager/manager_reader_progress.dart';
import 'package:flutter_novel/app/novel/widget/reader/model/model_reader_config.dart';
import 'package:flutter_novel/app/novel/widget/reader/model/model_reader_content.dart';
import 'package:flutter_novel/base/structure/base_view_model.dart';

typedef void OnRequestContent<T>(int novelId, int volumeId, int chapterId);
typedef void OnContentChanged(ReaderOperateEnum currentContentOperate);

class NovelReaderViewModel extends BaseViewModel {
  NovelBookInfo bookInfo;

  NovelReaderContentModel _contentModel;
  NovelReaderConfigModel _configModel;
  NovelBookNetModel _netModel;
  NovelBookCacheModel _cacheModel;
  NovelBookDBModel _dbModel;

  ReaderProgressManager progressManager;

  OnContentChanged contentChangedCallback;

  Paint bgPaint = Paint();

  TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);

  factory NovelReaderViewModel(
          NovelBookInfo bookInfo,
          NovelBookNetModel netModel,
          NovelBookCacheModel cacheModel,
          NovelBookDBModel dbModel) =>
      NovelReaderViewModel._(bookInfo, netModel, cacheModel, dbModel);

  NovelReaderViewModel._(NovelBookInfo bookInfo, NovelBookNetModel netModel,
      NovelBookCacheModel cacheModel, NovelBookDBModel dbModel) {
    this.bookInfo = bookInfo;

    _contentModel = NovelReaderContentModel(this);
    _configModel = NovelReaderConfigModel(this);
    progressManager = ReaderProgressManager(this);
    _dbModel = dbModel;
    _netModel = netModel;
    _cacheModel = cacheModel;
  }

  @override
  Widget getProviderContainer() {
    return null;
  }

  void registerContentOperateCallback(OnContentChanged contentChangedCallback) {
    this.contentChangedCallback = contentChangedCallback;
  }

  void updateChapterIndex(int chapterIndex) {}

  /// ---------------------------- 配置相关 ------------------------------------

  void setPageSize(Offset size){
    if(_configModel.configEntity.pageSize.dx!=size.dx||_configModel.configEntity.pageSize.dy!=size.dy){
      _configModel.configEntity.pageSize=size;
      reApplyConfig(true,false);
    }
  }

  void setCurrentConfig(ReaderConfigEntity configData) {
    _configModel.configEntity = configData.copy();

    if (_configModel.configEntity.currentCanvasBgColor != null) {
      bgPaint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.fill //填充
        ..color = _configModel.configEntity.currentCanvasBgColor; //背景为纸黄色

      textPainter = TextPainter(textDirection: TextDirection.ltr);
    }
  }

  void setMenuOpenState(bool isOpen) {
    _configModel.isMenuOpen = isOpen;
//    notifyRefresh();
  }

  bool getMenuOpenState() {
    return _configModel.isMenuOpen;
  }

  void setCatalogData(String novelId, int chapterIndex, int pageIndex,
      NovelBookChapter catalog) async {
    _configModel.catalog = catalog;

    (_contentModel.dataValue ??= ReaderContentDataValue())
      ..novelId = novelId
      ..currentPageIndex = pageIndex
      ..chapterIndex = chapterIndex;

    (_contentModel.preDataValue ??= ReaderContentDataValue())
      ..novelId = novelId;
    (_contentModel.nextDataValue ??= ReaderContentDataValue())
      ..novelId = novelId;

    if (isHasPreChapter()) {
      _contentModel.preDataValue.chapterIndex =
          _contentModel.dataValue.chapterIndex - 1;
    } else {
      _contentModel.preDataValue..chapterIndex = -1;
    }

    if (isHasNextChapter()) {
      _contentModel.nextDataValue.chapterIndex =
          _contentModel.dataValue.chapterIndex + 1;
    } else {
      _contentModel.nextDataValue..chapterIndex = -1;
    }

    _contentModel?.startParseLooper();

    checkPageCache();
    checkChapterCache();
  }

  void setFontSize(int size) {
    _configModel.configEntity.fontSize = size;
    reApplyConfig(true,true);
  }

  void setAnimationMode(int mode) {
    _configModel.configEntity.currentAnimationMode = mode;
    notifyRefresh();
  }

  void setLineHeight(int height) {
    _configModel.configEntity.lineHeight = height;
    reApplyConfig(true,true);
  }

  void setParagraphSpacing(int spacing) {
    _configModel.configEntity.paragraphSpacing = spacing;
    reApplyConfig(true,true);
  }

  void setBgColor(Color color) {
    bgPaint.color = color;
    reApplyConfig(false,true);
  }

  void reApplyConfig(bool reCalculate,bool isNotify) {
    var currentDataValue = _contentModel.dataValue;
    var preDataValue = _contentModel.preDataValue;
    var nextDataValue = _contentModel.nextDataValue;

    currentDataValue?.chapterCanvasDataMap?.clear();
    preDataValue?.chapterCanvasDataMap?.clear();
    nextDataValue?.chapterCanvasDataMap?.clear();

    if(isNotify) {
      notifyRefresh();
    }

    _contentModel?.contentParseQueue?.clear();
    _contentModel?.microContentParseQueue?.clear();

    if (reCalculate) {
      if(currentDataValue!=null) {
        parseChapterContent(ReaderParseContentDataValue(
            currentDataValue.contentData,
            currentDataValue.novelId,
            currentDataValue.title,
            currentDataValue.chapterIndex));
      }
      if(preDataValue!=null) {
        parseChapterContent(
            ReaderParseContentDataValue(preDataValue.contentData,
                preDataValue.novelId, preDataValue.title,
                preDataValue.chapterIndex));
      }
      if(nextDataValue!=null) {
        parseChapterContent(ReaderParseContentDataValue(
            nextDataValue.contentData,
            nextDataValue.novelId,
            nextDataValue.title,
            nextDataValue.chapterIndex));
      }
    } else {
      loadReaderContentDataValue(currentDataValue.chapterContentConfigs,
          currentDataValue, true, false);
      loadReaderContentDataValue(
          preDataValue.chapterContentConfigs, preDataValue, true, false);
      loadReaderContentDataValue(
          nextDataValue.chapterContentConfigs, nextDataValue, true, false);
    }
  }

  ReaderConfigEntity getConfigData() {
    return _configModel.configEntity;
  }

  NovelBookChapter getCatalog() {
    return _configModel.catalog;
  }

  /// --------------------------- 网络数据处理 ---------------------------------

  void requestNewContent(Chapters chapterData) async {
    if (isDisposed) {
      return;
    }

    String txt = await rootBundle.loadString('resource/Section0002.xhtml');
    String content = _parseHtmlString(txt);

    parseChapterContent(ReaderParseContentDataValue(content,
        chapterData.novelId, chapterData.title, chapterData.order - 1));


//    String originalContent =
//        await _cacheModel.getCacheChapterContent(chapterData.link);
//    if (originalContent == null) {
//      parseChapterContent(ReaderParseContentDataValue(
//          null, chapterData.novelId, chapterData.title, chapterData.order - 1)
//        ..contentState = ContentState.STATE_NOT_FOUND);
//    } else {
//      String content = _parseHtmlString(
//          json.decode(originalContent)["chapter"]["cpContent"]);
//      parseChapterContent(ReaderParseContentDataValue(content,
//          chapterData.novelId, chapterData.title, chapterData.order - 1));
//    }
  }

  void requestCatalog(String novelId) async {
    if (isDisposed) {
      return;
    }
    var sourceInfo = await _netModel.getNovelBookSource(novelId);
    if (sourceInfo?.data != null && sourceInfo.data.length > 0) {
      var result = await _netModel.getNovelBookCatalog(sourceInfo.data[0].id);
      if (result.isSuccess && result?.data != null) {
        setCatalogData(novelId, bookInfo.currentChapterIndex,
            bookInfo.currentPageIndex, result.data);
      }
    }
  }

  String _parseHtmlString(String htmlString) {
    if (htmlString == null || htmlString.length == 0) {
      return "加载出错，内容为空";
    }

    var document = parse(htmlString);

    String parsedString = parse(document.body.text).documentElement.text;

    print('-----$parsedString--------------------------');

    return parsedString.replaceAll("\n\n", "\n").trim();
  }

  /// --------------------------- 数据转换处理 ---------------------------------

  void parseChapterContent(ReaderParseContentDataValue contentData) {
    if (isDisposed) {
      return;
    }
    _contentModel.parseChapterContent(contentData);
  }

  void loadReaderContentDataValue(List<ReaderChapterPageContentConfig> configs,
      ReaderContentDataValue targetData, bool isCurrent, bool isPre) {
    _contentModel.loadReaderContentDataValue(
        configs, targetData, isCurrent, isPre);
  }

  void checkChapterCache() {
    progressManager.checkChapterCache();
  }

  void checkPageCache() {
    progressManager.checkPageCache();
  }

  ReaderContentDataValue getCurrentContentDataValue() {
    return _contentModel.dataValue;
  }

  ReaderContentDataValue getPreContentDataValue() {
    return _contentModel.preDataValue;
  }

  ReaderContentDataValue getNextContentDataValue() {
    return _contentModel.nextDataValue;
  }

  void setCurrentContentDataValue(ReaderContentDataValue dataValue) {
    _contentModel.dataValue = dataValue;
  }

  void setPreContentDataValue(ReaderContentDataValue dataValue) {
    _contentModel.preDataValue = dataValue;
  }

  void setNextContentDataValue(ReaderContentDataValue dataValue) {
    _contentModel.nextDataValue = dataValue;
  }

  ListQueue<ReaderContentDataValue> getMicroContentParseQueue() {
    return _contentModel.microContentParseQueue;
  }

  ListQueue<ReaderContentDataValue> getContentParseQueue() {
    return _contentModel.contentParseQueue;
  }

  /// ------------------------- 进度相关部分 -----------------------------------

  bool isCanGoNext() {
    return progressManager.isCanGoNext();
  }

  bool isHasNextChapter() {
    return progressManager.isHasNextChapter();
  }

  bool isCanGoPre() {
    return progressManager.isCanGoPre();
  }

  bool isHasPrePage() {
    return progressManager.isHasPrePage();
  }

  bool isHasPreChapter() {
    return progressManager.isHasPreChapter();
  }

  void nextPage() async {
    progressManager.nextPage();
  }

  void prePage() async {
    progressManager.prePage();
  }

  Future<bool> goToTargetPage(int index) async {
    if (contentChangedCallback != null) {
      contentChangedCallback(ReaderOperateEnum.OPERATE_JUMP_PAGE);
    }
    return progressManager.goToTargetPage(index);
  }

  Future<bool> goToTargetChapter(int index) async {
    if (contentChangedCallback != null) {
      contentChangedCallback(ReaderOperateEnum.OPERATE_JUMP_CHAPTER);
    }
    return progressManager.goToTargetChapter(index);
  }

  Future<bool> goToNextChapter() async {
    if (contentChangedCallback != null) {
      contentChangedCallback(ReaderOperateEnum.OPERATE_NEXT_CHAPTER);
    }
    return await progressManager.goToNextChapter(true);
  }

  Future<bool> goToPreChapter() async {
    if (contentChangedCallback != null) {
      contentChangedCallback(ReaderOperateEnum.OPERATE_PRE_CHAPTER);
    }
    return await progressManager.goToPreChapter(true);
  }

  ReaderProgressStateEnum getCurrentState() {
    return progressManager.getCurrentProgressState();
  }

  /// --------------------------- 展示相关部分 ---------------------------------

  ReaderContentCanvasDataValue getPrePage() {
    ReaderContentCanvasDataValue result;

    if (progressManager.isHasPrePage()) {
      var prePageInfo = _contentModel.dataValue
          .chapterCanvasDataMap[_contentModel.dataValue.currentPageIndex - 1];
      result = ReaderContentCanvasDataValue()
        ..pagePicture = prePageInfo?.pagePicture
        ..pageImage = prePageInfo?.pageImage;
    } else if (progressManager.isHasPreChapter()) {
      var prePageInfo = _contentModel.preDataValue.chapterCanvasDataMap[
          _contentModel.preDataValue.chapterContentConfigs.length - 1];
      result = ReaderContentCanvasDataValue()
        ..pagePicture = prePageInfo?.pagePicture
        ..pageImage = prePageInfo?.pageImage;
    } else {
      result = null;
    }

    return result;
  }

  ReaderContentCanvasDataValue getCurrentPage() {
    if (_contentModel?.dataValue == null) {
      return null;
    }

    return _contentModel.dataValue
        .chapterCanvasDataMap[_contentModel.dataValue.currentPageIndex];
  }

  ReaderContentCanvasDataValue getNextPage() {
    ReaderContentCanvasDataValue result;

    if (progressManager.isHasNextPage()) {
      var nextPageInfo = _contentModel.dataValue
          .chapterCanvasDataMap[_contentModel.dataValue.currentPageIndex + 1];
      result = ReaderContentCanvasDataValue()
        ..pagePicture = nextPageInfo?.pagePicture
        ..pageImage = nextPageInfo?.pageImage;
    } else if (progressManager.isHasNextChapter()) {
      var nextPageInfo = _contentModel.nextDataValue.chapterCanvasDataMap[0];
      result = ReaderContentCanvasDataValue()
        ..pagePicture = nextPageInfo?.pagePicture
        ..pageImage = nextPageInfo?.pageImage;
    } else {
      result = null;
    }

    return result;
  }

  /// ---------------------------- DB相关部分 ----------------------------------

  void updateDBInfo() {
    ReaderContentDataValue dataValue = getCurrentContentDataValue();
    if (dataValue == null) {
      return;
    }
    _dbModel.updateBookInfo(bookInfo
      ..currentChapterIndex = dataValue.chapterIndex
      ..currentPageIndex = dataValue.currentPageIndex);
  }

  @override
  void dispose() {
    updateDBInfo();
    super.dispose();
    _configModel.clear();
    _contentModel.clear();

    progressManager = null;
    _configModel = null;
    _contentModel = null;
  }

  void notifyRefresh() {
    if(hasListeners){
      notifyListeners();
    }
  }
}
