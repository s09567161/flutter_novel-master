import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_novel/app/novel/view_model/view_model_novel_reader.dart';
import 'package:flutter_novel/app/novel/widget/reader/model/event_bus.dart';


class ReadImageController {



  factory ReadImageController() => _getInstance();
  static ReadImageController get instance => _getInstance();
  static ReadImageController _instance;
  
  List<BookContentImage> _bookContentImageList = [];

  ReadImageController._internal(){
    //初始化
  }

  static ReadImageController _getInstance() {
    if (_instance == null) {
      _instance = new ReadImageController._internal();
    }
    return _instance;
  }

  //加载网络图片 url:图片链接 index:图片所在页码
  ui.Image getNetBookContentImageByUrl(String url, int index, NovelReaderViewModel viewModel) {

    ui.Image image;
    String regxstring=r'http';
    String locData='';
    RegExp regExp = new RegExp(regxstring);
    bool isurl = regExp.hasMatch(url);

    if(!isurl){
      List<String> spliturl = url.split('..');
      url=spliturl.first;
      locData=spliturl.last;

    }
    //查找url是否存在已加载图片,存在则取出图片
    for (var item in _bookContentImageList) {
      if (item.url == url) {
        image = item.image;
        break;
      }
    }
    //不存在图片则异步加载图片
    if (image == null) {
        _loadImage(isurl?url:locData,isurl).then((value) {
          //加载成功，将图片与url对应保存
          print('-111-----------$value-----------------------------------');
          _bookContentImageList.add(BookContentImage(image: value, url: url));
          //通知页面进行渲染
          print('-----------刷新图片-----------------------------------');
          // viewModel.notifyRefresh();

          EventBus().send(ReadUpdateContentEvent,index);
        });
    } 

    return image;
  }


  Future<ui.Image> _loadImage(var path, bool isUrl)  {
    Completer<ui.Image> completer = Completer<ui.Image>();

    if (isUrl) {
      ImageStream stream = NetworkImage(path).resolve(ImageConfiguration.empty);
      void listener(ImageInfo frame, bool synchronousCall) {
        final ui.Image image = frame.image;
        completer.complete(image);
        stream.removeListener(ImageStreamListener(listener));
      }
      stream.addListener(ImageStreamListener(listener));
    } else {
      var base64decode = base64Decode(path);
      ImageStream stream = MemoryImage(File(base64decode.toString()).readAsBytesSync()).resolve(ImageConfiguration.empty);
      void listener(ImageInfo frame, bool synchronousCall) {
        final ui.Image image = frame.image;
        completer.complete(image);
        stream.removeListener(ImageStreamListener(listener));
      }

      stream.addListener(ImageStreamListener(listener));
    }




    return completer.future;
  }
  
  void dispose() {
  }
}

class BookContentImage {
  String url;
  ui.Image image;

  BookContentImage({this.url, this.image});

}