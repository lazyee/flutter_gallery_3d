import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class Gallery3D extends StatefulWidget {
  final double? height;
  final double width;
  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<int>? onItemChanged;
  final ValueChanged<int>? onClickItem;
  final Gallery3DController controller;
  final GalleryItemConfig itemConfig;
  final EdgeInsetsGeometry? padding;
  final bool isClip;

  Gallery3D(
      {Key? key,
      this.onClickItem,
      this.onItemChanged,
      this.isClip = true,
      this.height,
      this.padding,
      required this.itemConfig,
      required this.controller,
      required this.width,
      required this.itemBuilder})
      : super(key: key);

  @override
  _Gallery3DState createState() => _Gallery3DState();
}

class _Gallery3DState extends State<Gallery3D>
    with TickerProviderStateMixin, WidgetsBindingObserver, Gallery3DMixin {
  List<Widget> _galleryItemWidgetList = [];
  AnimationController? _autoScrollAnimationController;
  Timer? _timer;

  late Gallery3DController controller = widget.controller;

  ///生命周期状态,
  AppLifecycleState appLifecycleState = AppLifecycleState.resumed;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    appLifecycleState = state;
    super.didChangeAppLifecycleState(state);
  }

  @override
  void initState() {
    controller.widgetWidth = widget.width;
    controller.vsync = this;
    controller.init(widget.itemConfig);

    _updateWidgetIndexOnStack();
    if (controller.autoLoop) {
      this._timer =
          Timer.periodic(Duration(milliseconds: controller.delayTime), (timer) {
        if (!mounted) return;
        if (appLifecycleState != AppLifecycleState.resumed) return;
        if (DateTime.now().millisecondsSinceEpoch - _lastTouchMillisecond <
            controller.delayTime) return;
        if (_isTouching) return;
        animateTo(controller.getOffsetAngleFormTargetIndex(
            getNextIndex(controller.currentIndex)));
      });
    }

    WidgetsBinding.instance.addObserver(this);

    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
    _autoScrollAnimationController?.stop(canceled: true);
    super.dispose();
  }

  @override
  void animateTo(angle) {
    _isTouching = true;
    _lastTouchMillisecond = DateTime.now().millisecondsSinceEpoch;
    _scrollToAngle(angle);
  }

  @override
  void jumpTo(angle) {
    setState(() {
      _updateAllGalleryItemTransformByAngle(angle);
    });
  }

  var _isTouching = false;
  var _lastTouchMillisecond = 0;
  Offset? _panDownLocation;
  Offset? _lastUpdateLocation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height ?? widget.itemConfig.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragCancel: (() {
          _onFingerUp();
        }),
        onHorizontalDragDown: (details) {
          _isTouching = true;
          _panDownLocation = details.localPosition;
          _lastUpdateLocation = details.localPosition;
          _lastTouchMillisecond = DateTime.now().millisecondsSinceEpoch;
        },
        onHorizontalDragEnd: (details) {
          _onFingerUp();
        },
        onHorizontalDragStart: (details) {},
        onHorizontalDragUpdate: (details) {
          setState(() {
            _lastUpdateLocation = details.localPosition;
            _lastTouchMillisecond = DateTime.now().millisecondsSinceEpoch;
            _updateAllGalleryItemTransformByOffsetDx(details.delta.dx);
          });
        },
        child: _buildWidgetList(),
      ),
    );
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

  void _scrollToAngle(double angle) {
    _autoScrollAnimationController =
        AnimationController(duration: Duration(milliseconds: 400), vsync: this);

    Animation animation;

    if (angle.ceil().abs() == 0) return;
    animation =
        Tween(begin: 0.0, end: angle).animate(_autoScrollAnimationController!);

    double lastValue = 0;
    animation.addListener(() {
      setState(() {
        _updateAllGalleryItemTransformByAngle(animation.value - lastValue);
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

  //自动滚动,在手指抬起或者cancel回调的时候调用
  void _onFingerUp() {
    if (_lastUpdateLocation == null) {
      _isTouching = false;
      return;
    }
    double angle = controller.getTransformInfo(controller.currentIndex).angle;
    double targetAngle = 0;

    var offsetX = _lastUpdateLocation!.dx - _panDownLocation!.dx;
    if (offsetX.abs() > widget.width * 0.1) {
      targetAngle = controller
              .getTransformInfo(offsetX > 0
                  ? getPreIndex(controller.currentIndex)
                  : getNextIndex(controller.currentIndex))
              .angle -
          180;
    } else {
      targetAngle = angle - 180;
    }

    _scrollToAngle(targetAngle);
  }

  void _updateAllGalleryItemTransformByAngle(double angle) {
    controller.updateTransformByAngle(angle);
    _updateAllGalleryItemTransform();
  }

  void _updateAllGalleryItemTransformByOffsetDx(double offsetDx) {
    controller.updateTransformByOffsetDx(offsetDx);
    _updateAllGalleryItemTransform();
  }

  void _updateAllGalleryItemTransform() {
    for (var i = 0; i < controller.getTransformInfoListSize(); i++) {
      var item = controller.getTransformInfo(i);

      if (item.angle > 180 - controller.unitAngle / 2 &&
          item.angle < 180 + controller.unitAngle / 2) {
        if (controller.currentIndex != i) {
          controller.currentIndex = i;
          widget.onItemChanged?.call(controller.currentIndex);
        }
      }
      _updateWidgetIndexOnStack();
    }
  }

  ///获取传入index的上一个index
  int getPreIndex(int index) {
    var preIndex = index - 1;
    if (preIndex < 0) {
      preIndex = controller.itemCount - 1;
    }
    return preIndex;
  }

  ///获取传入index的下一个index
  int getNextIndex(int index) {
    var nextIndex = index + 1;
    if (nextIndex == controller.itemCount) {
      nextIndex = 0;
    }
    return nextIndex;
  }

  List<GalleryItem> _leftWidgetList = [];
  List<GalleryItem> _rightWidgetList = [];
  List<GalleryItem> _tempList = [];

  ///改变的widget的在Stack中的顺序
  void _updateWidgetIndexOnStack() {
    _leftWidgetList.clear();
    _rightWidgetList.clear();
    _tempList.clear();
    for (var i = 0; i < controller.getTransformInfoListSize(); i++) {
      var angle = controller.getTransformInfo(i).angle;

      if (angle >= 180 + controller.unitAngle / 2) {
        _leftWidgetList.add(_buildGalleryItem(i));
      } else {
        _rightWidgetList.add(_buildGalleryItem(i));
      }
    }

    _rightWidgetList.sort((widget1, widget2) =>
        widget1.transformInfo.angle.compareTo(widget2.transformInfo.angle));

    _rightWidgetList.forEach((element) {
      if (element.transformInfo.angle < controller.unitAngle / 2) {
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
      ellipseHeight: controller.ellipseHeight,
      builder: widget.itemBuilder,
      config: widget.itemConfig,
      onClick: (index) {
        if (widget.onClickItem != null && index == controller.currentIndex) {
          widget.onClickItem?.call(index);
        }
      },
      transformInfo: controller.getTransformInfo(index),
    );
  }
}

class _GalleryItemTransformInfo {
  Offset offset;
  double scale;
  double angle;
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

  final double minScale; //最小缩放值
  GalleryItem({
    Key? key,
    required this.index,
    required this.transformInfo,
    required this.config,
    required this.builder,
    this.minScale = 0.4,
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

class Gallery3DController {
  double perimeter = 0; //周长
  double unitAngle = 0; //单位角度
  final double minScale; //最小缩放值
  double widgetWidth = 0; //控件宽度
  double ellipseHeight; //椭圆高度
  int itemCount;
  late GalleryItemConfig itemConfig;
  int currentIndex = 0;
  final int delayTime;
  final int scrollTime;
  final bool autoLoop;
  late Gallery3DMixin vsync;
  List<_GalleryItemTransformInfo> _galleryItemTransformInfoList = [];
  double baseAngleOffset = 0; //180度的基准角度偏差
  Gallery3DController(
      {required this.itemCount,
      this.ellipseHeight = 0,
      this.autoLoop = true,
      this.minScale = 0.4,
      this.delayTime = 5000,
      this.scrollTime = 1000})
      : assert(itemCount >= 3, 'ItemCount must be greater than or equal to 3');

  void init(GalleryItemConfig itemConfig) {
    this.itemConfig = itemConfig;
    unitAngle = 360 / itemCount;
    // perimeter = calculatePerimeter(itemConfig.width * 0.8, 50);
    perimeter = calculatePerimeter(widgetWidth * 0.7, 50);

    _galleryItemTransformInfoList.clear();
    for (var i = 0; i < itemCount; i++) {
      var itemAngle = getItemAngle(i);
      _galleryItemTransformInfoList.add(_GalleryItemTransformInfo(
          index: i,
          angle: itemAngle,
          scale: calculateScale(itemAngle),
          offset: calculateOffset(itemAngle)));
    }
  }

  _GalleryItemTransformInfo getTransformInfo(int index) {
    return _galleryItemTransformInfoList[index];
  }

  int getTransformInfoListSize() {
    return _galleryItemTransformInfoList.length;
  }

  double getItemAngle(int index) {
    double angle = 360 - (index * unitAngle + 180) % 360;
    return angle;
  }

  void updateTransformByAngle(double offsetAngle) {
    baseAngleOffset -= offsetAngle;
    for (int index = 0; index < _galleryItemTransformInfoList.length; index++) {
      _GalleryItemTransformInfo transformInfo =
          _galleryItemTransformInfoList[index];

      double angle = getItemAngle(index);
      double scale = transformInfo.scale;
      Offset offset = transformInfo.offset;

      if (baseAngleOffset.abs() > 360) {
        baseAngleOffset %= 360;
      }

      angle += baseAngleOffset;
      angle = angle % 360;

      //计算椭圆轨迹的点
      offset = calculateOffset(angle);

      ///计算缩放参数
      scale = calculateScale(angle);

      transformInfo
        ..angle = angle
        ..scale = scale
        ..offset = offset;
    }
  }

  ///更新偏移数据
  void updateTransformByOffsetDx(double offsetDx) {
    double offsetAngle = offsetDx / perimeter / 2 * 360;
    updateTransformByAngle(offsetAngle);
  }

  ///计算缩放参数
  double calculateScale(double angle) {
    angle = angle % 360;
    if (angle > 180) {
      angle = 360 - angle;
    }

    angle += 30; //修正一下，视觉效果貌似更好

    var scale = angle / 180.0;

    if (scale > 1) {
      scale = 1;
    } else if (scale < minScale) {
      scale = minScale;
    }

    return scale;
  }

  ///计算椭圆轨迹的点
  Offset calculateOffset(double angle) {
    double width = widgetWidth * 0.7; //椭圆宽
    double radiusOuterX = width / 2;
    double radiusOuterY = ellipseHeight;

    double angleOuter = (2 * pi / 360) * angle;
    double x = radiusOuterX * sin(angleOuter);
    double y = radiusOuterY > 0 ? radiusOuterY * cos(angleOuter) : 0;
    return Offset(x + (widgetWidth - itemConfig.width) / 2, -y);
  }

  ///计算椭圆周长
  double calculatePerimeter(double width, double height) {
    // 椭圆周长公式：L=2πb+4(a-b)
    var a = width;
    // var a = width * 0.8;
    var b = height;
    return 2 * pi * b + 4 * (a - b);
  }

  ///获取最终的angle
  double getFinalAngle(double angle) {
    if (angle >= 360) {
      angle -= 360;
    } else if (angle < 0) {
      angle += 360;
    }
    return angle;
  }

  double getOffsetAngleFormTargetIndex(int index) {
    double targetItemAngle = getItemAngle(index) + baseAngleOffset;

    double offsetAngle = targetItemAngle % 180;
    if (targetItemAngle < 180 || targetItemAngle > 360) {
      offsetAngle = offsetAngle - 180;
    }

    return offsetAngle;
  }

  void animateTo(int index) {
    if (index == currentIndex) return;
    vsync.animateTo(getOffsetAngleFormTargetIndex(index));
  }

  void jumpTo(int index) {
    if (index == currentIndex) return;
    vsync.jumpTo(getOffsetAngleFormTargetIndex(index));
  }
}

mixin class Gallery3DMixin {
  void animateTo(angle) {}
  void jumpTo(angle) {}
}
