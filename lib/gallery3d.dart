import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class Gallery3D extends StatefulWidget {
  final int itemCount;
  final GalleryItemConfig itemConfig;
  final double? height;
  final double width;
  final bool autoLoop;
  final int delayTime;
  final int scrollTime;
  final int currentIndex;
  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<int>? onItemChanged;
  final ValueChanged<int>? onClickItem;
  final double ellipseHeight; //椭圆轨迹高度
  final bool isClip;

  Gallery3D(
      {Key? key,
      this.autoLoop = true,
      this.delayTime = 5000,
      this.scrollTime = 1000,
      this.currentIndex = 0,
      this.onClickItem,
      this.onItemChanged,
      this.ellipseHeight = 0,
      this.isClip = true,
      this.height,
      required this.width,
      required this.itemConfig,
      required this.itemCount,
      required this.itemBuilder})
      : assert(itemCount >= 3, 'ItemCount must be greater than or equal to 3'),
        super(key: key);

  @override
  _Gallery3DState createState() => _Gallery3DState();
}

class _Gallery3DState extends State<Gallery3D>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  List<Widget> _galleryItemWidgetList = [];
  AnimationController? _timerAnimationController;
  Animation? _timerAnimation;
  AnimationController? _autoScrollAnimationController;
  double _perimeter = 0;
  Timer? _timer;
  List<_GalleryItemTransformInfo> _galleryItemTransformInfoList = [];
  double _unitAngle = 0; //单位角度
  late int _currentIndex = widget.currentIndex; //当前索引
  double _minScale = 0.8; //最小缩放值

  ///生命周期状态,
  AppLifecycleState appLifecycleState = AppLifecycleState.resumed;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    appLifecycleState = state;
    super.didChangeAppLifecycleState(state);
  }

  final int _minAnimMilliseconds = 200;
  int _getAnimMilliseconds(int milliseconds) {
    if (milliseconds < _minAnimMilliseconds) {
      return _minAnimMilliseconds;
    }
    return milliseconds;
  }

  @override
  void initState() {
    _unitAngle = 360 / widget.itemCount;
    _initGalleryTransformInfoMap();
    _updateWidgetIndexOnStack();
    if (widget.autoLoop) {
      _perimeter = calculatePerimeter(widget.itemConfig.width * 0.8, 50);
      this._timer =
          Timer.periodic(Duration(milliseconds: widget.delayTime), (timer) {
        if (!mounted) return;
        if (appLifecycleState != AppLifecycleState.resumed) return;
        if (DateTime.now().millisecondsSinceEpoch - _lastTouchMillisecond <
            widget.delayTime) return;
        if (_isTouching) return;

        _timerAnimationController = AnimationController(
            duration: Duration(
                milliseconds: _getAnimMilliseconds(
                    widget.scrollTime ~/ widget.itemCount)),
            vsync: this);
        _timerAnimation = Tween(
          begin: 0.0,
          end: (-_perimeter / widget.itemCount).toDouble(),
        ).animate(_timerAnimationController!);

        double last = 0;
        _timerAnimation?.addListener(() {
          if (_isTouching) return;
          setState(() {
            _updateAllGalleryItemTransform(_timerAnimation?.value - last);
            last = _timerAnimation?.value;
          });
        });
        _timerAnimationController?.forward();
      });
    }

    WidgetsBinding.instance?.addObserver(this);

    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance?.removeObserver(this);
    _timer?.cancel();
    _timer = null;
    _timerAnimationController?.stop(canceled: true);
    _autoScrollAnimationController?.stop(canceled: true);
    super.dispose();
  }

  var _isTouching = false;
  var _lastTouchMillisecond = 0;
  Offset? _panDownLocation;
  Offset? _lastUpdateLocation;
  int _panDownIndex = -1; //在手指按下的时候的index
  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height ?? widget.itemConfig.height,
      padding: EdgeInsets.fromLTRB(
          0, widget.ellipseHeight / 2, 0, widget.ellipseHeight / 2),
      child: GestureDetector(
        //按下
        onPanDown: (details) {
          _panDownIndex = _currentIndex;
          _isTouching = true;
          _panDownLocation = details.localPosition;
          _lastUpdateLocation = details.localPosition;
          _lastTouchMillisecond = DateTime.now().millisecondsSinceEpoch;
        },
        //抬起
        onPanEnd: (details) {
          _autoScrolling();
        },
        //结束
        onPanCancel: () {
          _autoScrolling();
        },
        //更新
        onPanUpdate: (details) {
          setState(() {
            _lastUpdateLocation = details.localPosition;
            _lastTouchMillisecond = DateTime.now().millisecondsSinceEpoch;
            _updateAllGalleryItemTransform(details.delta.dx);
          });
        },
        child: _buildWidgetList(),
      ),
    );
  }

  ///获取最终的scale
  double getFinalScale(double scale) {
    if (scale > 1) {
      scale = 1 - scale % 1.0;
    }
    if (scale < _minScale) {
      scale = _minScale;
    }
    return scale;
  }

  ///计算缩放参数
  double calculateScale(int angle) {
    var tempScale = angle / 180.0;
    tempScale = 1 - (1 - tempScale) * 0.4;
    return getFinalScale(tempScale);
  }

  ///计算椭圆轨迹的点
  Offset calculateOffset(int angle) {
    double width = widget.width * 0.7; //椭圆宽
    double radiusOuterX = width / 2;
    double radiusOuterY = widget.ellipseHeight;

    double angleOuter = (2 * pi / 360) * angle;
    double x = radiusOuterX * sin(angleOuter);
    double y = radiusOuterY > 0 ? radiusOuterY * cos(angleOuter) : 0;
    return Offset(x + (widget.width - widget.itemConfig.width) / 2, -y);
  }

  ///计算椭圆周长
  double calculatePerimeter(double width, double height) {
    // 椭圆周长公式：L=2πb+4(a-b)
    var a = width * 0.8;
    var b = height;
    return 2 * pi * b + 4 * (a - b);
  }

  ///获取最终的angle
  int getFinalAngle(num angle) {
    if (angle >= 360) {
      angle -= 360;
    } else if (angle < 0) {
      angle += 360;
    }
    return angle.round();
  }

  ///更新偏移数据
  void updateTransform(int index, double offsetDx) {
    _GalleryItemTransformInfo transformInfo =
        _galleryItemTransformInfoList[index];
    // if (offsetDx == 0) return;
    // 需要计算出当前位移对应的夹角,再进行计算对应的x轴坐标点
    if (_perimeter == 0) {
      _perimeter = calculatePerimeter(widget.itemConfig.width * 0.8, 50);
    }

    int angle = transformInfo.angle;
    double scale = transformInfo.scale;
    Offset offset = transformInfo.offset;

    int offsetAngle = (offsetDx.abs() / _perimeter * 360).round();
    if (offsetDx > 0) {
      angle -= offsetAngle;
    } else {
      angle += offsetAngle;
    }
    angle = getFinalAngle(angle);

    //计算椭圆轨迹的点
    offset = calculateOffset(angle);

    ///计算缩放参数
    scale = calculateScale(angle);

    _galleryItemTransformInfoList[index]
      ..angle = angle
      ..scale = scale
      ..offset = offset;
  }

  Widget _buildWidgetList() {
    if (widget.isClip) {
      return ClipRect(
          child: Stack(
        children: _galleryItemWidgetList,
      ));
    }
    return Stack(
      children: _galleryItemWidgetList,
    );
  }

  //自动滚动,在手指抬起或者cancel回调的时候调用
  void _autoScrolling() {
    if (_lastUpdateLocation == null) {
      _isTouching = false;
      return;
    }
    int angle = _galleryItemTransformInfoList[_currentIndex].angle;

    _autoScrollAnimationController = AnimationController(
        duration: Duration(
            milliseconds: _getAnimMilliseconds(widget.scrollTime ~/
                widget.itemCount *
                (angle % _unitAngle) ~/
                _unitAngle)),
        vsync: this);
    Animation animation;
    double target = 0;

    var offsetX = _lastUpdateLocation!.dx - _panDownLocation!.dx;
    //当偏移量超过屏幕的10%宽度的时候且手指按下时候的索引和手指抬起来时候的索引一样的时候
    if (_panDownIndex == _currentIndex &&
        offsetX.abs() > MediaQuery.of(context).size.width * 0.1) {
      if (offsetX > 0) {
        target = (angle - 180 + _unitAngle) / 360 * _perimeter;
      } else {
        target = -(180 + _unitAngle - angle) / 360 * _perimeter;
      }
    } else {
      if (angle > 180) {
        target = (angle - 180) / 360 * _perimeter;
      } else {
        target = -(180 - angle) / 360 * _perimeter;
      }
    }

    if (target == 0) return;
    animation =
        Tween(begin: 0.0, end: target).animate(_autoScrollAnimationController!);

    double lastValue = 0;
    animation.addListener(() {
      setState(() {
        _updateAllGalleryItemTransform(animation.value - lastValue);
        lastValue = animation.value;
      });
    });
    _autoScrollAnimationController?.forward();
    _autoScrollAnimationController?.addListener(() {
      if (_autoScrollAnimationController != null &&
          _autoScrollAnimationController!.isCompleted) {
        _isTouching = false;
      }
    });
  }

  void _updateAllGalleryItemTransform(double offsetDx) {
    for (var i = 0; i < _galleryItemTransformInfoList.length; i++) {
      updateTransform(i, offsetDx);
    }

    for (var i = 0; i < _galleryItemTransformInfoList.length; i++) {
      var item = _galleryItemTransformInfoList[i];

      if (item.angle > 180 - _unitAngle / 2 &&
          item.angle < 180 + _unitAngle / 2) {
        _currentIndex = i;

        Future.delayed(Duration.zero, () {
          widget.onItemChanged?.call(_currentIndex);
        });
      }
      _updateWidgetIndexOnStack();
    }
  }

  ///获取传入index的上一个index
  int getPreIndex(int index) {
    var preIndex = index - 1;
    if (preIndex < 0) {
      preIndex = widget.itemCount - 1;
    }
    return preIndex;
  }

  ///获取传入index的下一个index
  int getNextIndex(int index) {
    var nextIndex = index + 1;
    if (nextIndex == widget.itemCount) {
      nextIndex = 0;
    }
    return nextIndex;
  }

  void _initGalleryTransformInfoMap() {
    _galleryItemTransformInfoList.clear();
    for (var i = 0; i < widget.itemCount; i++) {
      var itemAngle = getFinalAngle(180 + _unitAngle * i);
      _galleryItemTransformInfoList.add(_GalleryItemTransformInfo(
          index: i,
          angle: itemAngle,
          scale: calculateScale(itemAngle),
          offset: calculateOffset(itemAngle)));
    }
  }

  List<GalleryItem> _leftWidgetList = [];
  List<GalleryItem> _rightWidgetList = [];
  List<GalleryItem> _tempList = [];

  ///改变的weiget的在Stack中的顺序
  void _updateWidgetIndexOnStack() {
    _leftWidgetList.clear();
    _rightWidgetList.clear();
    _tempList.clear();
    for (var i = 0; i < _galleryItemTransformInfoList.length; i++) {
      var angle = _galleryItemTransformInfoList[i].angle.ceil();
      if (angle >= 180 + _unitAngle / 2) {
        _leftWidgetList.add(_buildGalleryItem(i));
      } else {
        _rightWidgetList.add(_buildGalleryItem(i));
      }
    }

    _rightWidgetList.sort((widget1, widget2) =>
        widget1.transformInfo.angle.compareTo(widget2.transformInfo.angle));

    _rightWidgetList.forEach((element) {
      if (element.transformInfo.angle < _unitAngle / 2) {
        element.transformInfo.angle += 360;
        _tempList.add(element);
      }
    });
    _tempList.forEach((element) {
      _rightWidgetList.remove(element);
    });
    _leftWidgetList.insertAll(0, _tempList);
    _leftWidgetList.sort((widget1, widget2) =>
        widget2.transformInfo.angle.compareTo(widget1.transformInfo.angle));

    _galleryItemWidgetList = [
      ..._leftWidgetList,
      ..._rightWidgetList,
    ];
  }

  GalleryItem _buildGalleryItem(int index) {
    return GalleryItem(
      index: index,
      ellipseHeight: widget.ellipseHeight,
      builder: widget.itemBuilder,
      config: widget.itemConfig,
      onClick: (index) {
        if (widget.onClickItem != null && index == _currentIndex) {
          widget.onClickItem?.call(index);
        }
      },
      transformInfo: _galleryItemTransformInfoList[index],
    );
  }
}

class _GalleryItemTransformInfo {
  Offset offset;
  double scale;
  int angle;
  int index;

  _GalleryItemTransformInfo(
      {required this.index,
      this.scale = 1,
      this.angle = 0,
      this.offset = Offset.zero});
}

class GalleryItem extends StatelessWidget {
  final GalleryItemConfig config;
  final double ellipseHeight;
  final int index;
  final IndexedWidgetBuilder builder;
  final ValueChanged<int>? onClick;
  final _GalleryItemTransformInfo transformInfo;

  final double minScale; //   //最小缩放值
  GalleryItem({
    Key? key,
    required this.index,
    required this.transformInfo,
    required this.config,
    required this.builder,
    this.minScale = 0.8,
    this.onClick,
    this.ellipseHeight = 0,
  }) : super(key: key);

  Widget _buildItem(BuildContext context) {
    return Container(
        width: config.width,
        height: config.height,
        child: builder(context, index));
  }

  Widget _buildMaskTransformItem(Widget child) {
    if (!config.isShowTransformMask) return child;
    return Stack(children: [
      child,
      Container(
        width: config.width,
        height: config.height,
        color: Color.fromARGB(
            100 * (1 - transformInfo.scale) ~/ (1 - minScale), 0, 0, 0),
      )
    ]);
  }

  Widget _buildRadiusItem(Widget child) {
    if (config.radius <= 0) return child;
    return ClipRRect(
        borderRadius: BorderRadius.circular(config.radius), child: child);
  }

  Widget _buildShadowItem(Widget child) {
    if (config.shadows.isEmpty) return child;
    return Container(
        child: child, decoration: BoxDecoration(boxShadow: config.shadows));
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: transformInfo.offset,
      child: Container(
        width: config.width,
        height: config.height,
        child: Transform.scale(
          scale: transformInfo.scale,
          child: InkWell(
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            onTap: () => onClick?.call(index),
            child: _buildShadowItem(
                _buildRadiusItem(_buildMaskTransformItem(_buildItem(context)))),
          ),
        ),
      ),
    );
  }
}

///配置类
class GalleryItemConfig {
  final double width; //item的宽度
  final double height; //item的高度
  final double radius; //控制item的圆角
  final List<BoxShadow> shadows; //控制item的阴影
  final bool isShowTransformMask; //是否显示item的透明度蒙层的渐变

  const GalleryItemConfig(
      {this.width = 220,
      this.height = 300,
      this.radius = 0,
      this.isShowTransformMask = true,
      this.shadows = const []});
}
