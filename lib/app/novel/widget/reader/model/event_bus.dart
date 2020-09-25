//订阅者回调签名
typedef void EventCallback(arg);

///创建eventBus工具类
class EventBus {
  /// 私有构造函数
  EventBus._internal();

  /// 保存单例
  static EventBus _singleton = new EventBus._internal();

  /// 工厂构造函数
  factory EventBus() => _singleton;

  /// 保存事件订阅者队列，key:事件名(id)，value: 对应事件的订阅者队列
  var _eMap = new Map<Object, List<EventCallback>>();

  /// 添加订阅者
  void on(eventName, EventCallback f) {
    if (eventName == null || f == null) return;
    _eMap[eventName] ??= new List<EventCallback>();
    _eMap[eventName].add(f);
  }

  /// 移除订阅者
  void off(eventName, [EventCallback f]) {
    var list = _eMap[eventName];
    if (eventName == null || list == null) return;
    if (f == null) {
      _eMap[eventName] = null;
    } else {
      list.remove(f);
    }
  }

  /// 触发事件，事件触发后该事件所有订阅者会被调用
  void send(eventName, [arg]) {
    var list = _eMap[eventName];
    if (list == null) return;
    int len = list.length - 1;
    //反向遍历，防止订阅者在回调中移除自身带来的下标错位
    for (var i = len; i > -1; --i) {
      list[i](arg);
    }
  }
}

var bus = new EventBus();

/// 普通模式菜单状态改变
const String NormalMenuChangeEvent = "NormalMenuChange";
/// 语音阅读模式菜单状态改变
const String VoiceMenuChangeEvent = "VoiceMenuChange";
/// 阅读文本刷新
const String ReadContentRefreshEvent = "ReadContentRefresh";
/// 阅读文本刷新
const String ReadUpdateContentEvent = "ReadUpdateContent";
