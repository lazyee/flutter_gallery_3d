import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

// int minCount = 3;

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
  List<Widget> imageWidgetList = [];
  AnimationController? _timerAnimationController;
  Animation? _timerAnimation;
  AnimationController? _autoScrollAnimationController;
  double perimeter = 0;
  Timer? timer;
  Map<int, _GalleryItemTransformInfo> _galleryItemTransformInfoMap = {};

  ///单位角度
  double unitAngle = 0;

  ///当前索引
  int currentIndex = -1;

  ///生命周期状态,
  AppLifecycleState appLifecycleState = AppLifecycleState.resumed;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    appLifecycleState = state;
    super.didChangeAppLifecycleState(state);
  }

  @override
  void didUpdateWidget(covariant Gallery3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget != widget) {
      setState(() {
        _galleryItemTransformInfoMap.forEach((key, value) {
          updateTransform(key, 0);
        });
      });
    }
  }

  @override
  void initState() {
    unitAngle = 360 / widget.itemCount;
    _onFocusImageChanged(widget.currentIndex, 1, false);
    if (widget.autoLoop) {
      perimeter = calculatePerimeter(widget.itemConfig.itemWidth * 0.8, 50);
      this.timer =
          Timer.periodic(Duration(milliseconds: widget.delayTime), (timer) {
        if (!mounted) return;
        if (appLifecycleState != AppLifecycleState.resumed) return;
        if (DateTime.now().millisecondsSinceEpoch - lastTouchMillisecond <
            widget.delayTime) return;
        if (onTouching) return;
        var animMilliseconds = widget.scrollTime ~/ widget.itemCount;
        _timerAnimationController = AnimationController(
            duration: Duration(milliseconds: animMilliseconds), vsync: this);
        _timerAnimation = Tween(
          begin: 0.0,
          end: (-perimeter / widget.itemCount).toDouble(),
        ).animate(_timerAnimationController!);

        double last = 0;
        _timerAnimation?.addListener(() {
          if (onTouching) return;
          setState(() {
            var offsetDx = _timerAnimation?.value - last;
            _galleryItemTransformInfoMap.forEach((key, value) {
              updateTransform(key, offsetDx);
            });
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

    if (this.timer != null) {
      this.timer?.cancel();
    }
    if (_timerAnimationController != null) {
      _timerAnimationController?.stop(canceled: true);
    }
    if (_autoScrollAnimationController != null) {
      _autoScrollAnimationController?.stop(canceled: true);
    }
    super.dispose();
  }

  var onTouching = false;
  var lastTouchMillisecond = 0;
  Offset? panDownLocation;
  Offset? lastUpdateLocation;
  int onPanDownIndex = -1; //在手指按下的时候的index
  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height ?? widget.itemConfig.itemHeight,
      padding: EdgeInsets.fromLTRB(
          0, widget.ellipseHeight / 2, 0, widget.ellipseHeight / 2),
      child: GestureDetector(
        //按下
        onPanDown: (details) {
          onPanDownIndex = currentIndex;
          onTouching = true;
          panDownLocation = details.localPosition;
          lastUpdateLocation = details.localPosition;
          lastTouchMillisecond = DateTime.now().millisecondsSinceEpoch;
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
            lastUpdateLocation = details.localPosition;
            lastTouchMillisecond = DateTime.now().millisecondsSinceEpoch;
            var dx = details.delta.dx;
            _galleryItemTransformInfoMap.forEach((key, value) {
              updateTransform(key, dx);
            });
          });
        },
        child: _buildImageWidgetList(),
      ),
    );
  }

  ///获取最终的scale
  double getFinalScale(double scale) {
    if (scale > 1) {
      scale = 1 - scale % 1.0;
    }
    if (scale < minScale) {
      scale = minScale;
    }
    return scale;
  }

  //最小缩放值
  double minScale = 0.8;

  // ///计算缩放参数
  double calculateScale(double angle) {
    var tempScale = angle / 180.0;
    tempScale = 1 - (1 - tempScale) * 0.4;
    return getFinalScale(tempScale);
  }

  //计算椭圆轨迹的点
  Offset calculateOffset(double angle) {
    double width = widget.width * 0.7; //椭圆宽
    double radiusOuterX = width / 2;
    double radiusOuterY = widget.ellipseHeight;

    double angleOuter = (2 * pi / 360) * angle;
    double x = radiusOuterX * sin(angleOuter);
    double y = radiusOuterY > 0 ? radiusOuterY * cos(angleOuter) : 0;
    return Offset(x + (widget.width - widget.itemConfig.itemWidth) / 2, -y);
  }

  ///计算椭圆周长
  double calculatePerimeter(double width, double height) {
    // 椭圆周长公式：L=2πb+4(a-b)
    var a = width * 0.8;
    var b = height;
    return 2 * pi * b + 4 * (a - b);
  }

  ///获取最终的angle
  double getFinalAngle(double angle) {
    if (angle > 360) {
      angle -= 360;
    } else if (angle < 0) {
      angle += 360;
    }
    return angle;
  }

  ///更新偏移数据
  void updateTransform(int key, double offsetDx) {
    _GalleryItemTransformInfo? transformInfo =
        _galleryItemTransformInfoMap[key];
    if (transformInfo == null) return;
    // if (offsetDx == 0) return;
    // 需要计算出当前位移对应的夹角,再进行计算对应的x轴坐标点
    if (perimeter == 0) {
      perimeter = calculatePerimeter(widget.itemConfig.itemWidth * 0.8, 50);
    }

    double offsetAngle = offsetDx.abs() / perimeter * 360;
    if (offsetDx > 0) {
      transformInfo.angle -= offsetAngle;
    } else {
      transformInfo.angle += offsetAngle;
    }
    transformInfo.angle = getFinalAngle(transformInfo.angle);

    if (transformInfo.angle > 180 - unitAngle / 2 &&
        transformInfo.angle < 180 + unitAngle / 2) {
      _onFocusImageChanged(key, offsetDx > 0 ? 1 : -1, true);
    }

    //计算椭圆轨迹的点
    transformInfo.offset = calculateOffset(transformInfo.angle);

    ///计算缩放参数
    transformInfo.scale = calculateScale(transformInfo.angle);
  }

  Widget _buildImageWidgetList() {
    if (widget.isClip) {
      return ClipRect(
          child: Stack(
        children: imageWidgetList,
      ));
    }
    return Stack(
      children: imageWidgetList,
    );
  }

  //自动滚动,在手指抬起或者cancel回调的时候调用
  void _autoScrolling() {
    if (lastUpdateLocation == null) return;
    double angle = _galleryItemTransformInfoMap[currentIndex]?.angle ?? 0;
    _autoScrollAnimationController =
        AnimationController(duration: Duration(milliseconds: 200), vsync: this);
    Animation animation;
    double target = 0;

    var offsetX = lastUpdateLocation!.dx - panDownLocation!.dx;
    //当偏移量超过屏幕的10%宽度的时候且手指按下时候的索引和手指抬起来时候的索引一样的时候
    if (onPanDownIndex == currentIndex &&
        offsetX.abs() > MediaQuery.of(context).size.width * 0.1) {
      if (offsetX > 0) {
        target = (angle - 180 + unitAngle) / 360 * perimeter;
      } else {
        target = -(180 + unitAngle - angle) / 360 * perimeter;
      }
    } else {
      if (angle > 180) {
        target = (angle - 180) / 360 * perimeter;
      } else {
        target = -(180 - angle) / 360 * perimeter;
      }
    }

    if (target == 0) return;
    animation =
        Tween(begin: 0.0, end: target).animate(_autoScrollAnimationController!);

    double lastValue = 0;
    animation.addListener(() {
      setState(() {
        var offsetDx = animation.value - lastValue;
        _galleryItemTransformInfoMap.forEach((key, value) {
          updateTransform(key, offsetDx);
        });
        lastValue = animation.value;
      });
    });
    _autoScrollAnimationController?.forward();
    _autoScrollAnimationController?.addListener(() {
      if (_autoScrollAnimationController != null &&
          _autoScrollAnimationController!.isCompleted) {
        onTouching = false;
      }
    });
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

  ///焦点图片改变的时候更新图片的在Stack中的顺序
  void _onFocusImageChanged(int index, int direction, bool refresh) {
    if (refresh) {
      Future.delayed(Duration.zero, () {
        widget.onItemChanged?.call(index);
      });
    }

    currentIndex = index;
    var preIndex = getPreIndex(currentIndex);
    var nextIndex = getNextIndex(currentIndex);

    List<Widget> widgetList = [];

    var forIndex = currentIndex - 1;
    for (var i = 1; i < widget.itemCount; i++) {
      if (forIndex < 0) {
        forIndex = widget.itemCount + forIndex;
      }
      if (forIndex != nextIndex && forIndex != preIndex) {
        widgetList.add(
            _buildGalleryItem(forIndex, false, 180 + unitAngle * i, unitAngle));
      }

      forIndex--;
    }

    //处理前一个和后一个Item在Stack中的层级
    if (refresh) {
      if (direction > 0) {
        if ((_galleryItemTransformInfoMap[currentIndex]?.angle ?? 0) < 180) {
          widgetList.add(
              _buildGalleryItem(nextIndex, false, 180 - unitAngle, unitAngle));
          widgetList.add(
              _buildGalleryItem(preIndex, false, unitAngle - 180, unitAngle));
        } else {
          widgetList.add(
              _buildGalleryItem(preIndex, false, unitAngle - 180, unitAngle));
          widgetList.add(
              _buildGalleryItem(nextIndex, false, 180 - unitAngle, unitAngle));
        }
      } else {
        if ((_galleryItemTransformInfoMap[currentIndex]?.angle ?? 0) < 180) {
          widgetList.add(
              _buildGalleryItem(nextIndex, false, 180 - unitAngle, unitAngle));
          widgetList.add(
              _buildGalleryItem(preIndex, false, unitAngle - 180, unitAngle));
        } else {
          widgetList.add(
              _buildGalleryItem(preIndex, false, unitAngle - 180, unitAngle));
          widgetList.add(
              _buildGalleryItem(nextIndex, false, 180 - unitAngle, unitAngle));
        }
      }
    } else {
      widgetList
          .add(_buildGalleryItem(preIndex, false, unitAngle - 180, unitAngle));
      widgetList
          .add(_buildGalleryItem(nextIndex, false, 180 - unitAngle, unitAngle));
    }

    widgetList.add(_buildGalleryItem(currentIndex, false, 180, unitAngle));

    imageWidgetList = widgetList;

    if (refresh) {
      setState(() {});
    }
  }

  Widget _buildGalleryItem(
      int index, bool isFocus, double angle, double unitAngle) {
    if (_galleryItemTransformInfoMap[index] == null) {
      _galleryItemTransformInfoMap[index] = _GalleryItemTransformInfo()
        ..angle = angle
        ..offset = calculateOffset(angle)
        ..scale = calculateScale(angle);
    }

    return GalleryItem(
      index: index,
      ellipseHeight: widget.ellipseHeight,
      builder: widget.itemBuilder,
      config: widget.itemConfig,
      onClick: (index) {
        if (widget.onClickItem != null && index == currentIndex) {
          widget.onClickItem?.call(index);
        }
      },
      transformInfo: _galleryItemTransformInfoMap[index]!,
    );
  }
}

class _GalleryItemTransformInfo {
  Offset offset = Offset.zero;
  double scale = 1;
  double angle = 0;

  _GalleryItemTransformInfo();
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
        width: config.itemWidth,
        height: config.itemHeight,
        child: builder(context, index));
  }

  Widget _buildMaskTransformItem(Widget child) {
    if (!config.isShowItemTransformMask) return child;
    return Stack(children: [
      child,
      Container(
        width: config.itemWidth,
        height: config.itemHeight,
        color: Color.fromARGB(
            100 * (1 - transformInfo.scale) ~/ (1 - minScale), 0, 0, 0),
      )
    ]);
  }

  Widget _buildRadiusItem(Widget child) {
    if (config.itemRadius <= 0) return child;
    return ClipRRect(
        borderRadius: BorderRadius.circular(config.itemRadius), child: child);
  }

  Widget _buildShadowItem(Widget child) {
    if (config.itemShadows.isEmpty) return child;
    return Container(
        child: child, decoration: BoxDecoration(boxShadow: config.itemShadows));
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: transformInfo.offset,
      child: Container(
        width: config.itemWidth,
        height: config.itemHeight,
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
  final double itemWidth; //item的宽度
  final double itemHeight; //item的高度
  final double itemRadius; //控制item的圆角
  final List<BoxShadow> itemShadows; //控制item的阴影
  final bool isShowItemTransformMask; //是否显示item的透明度蒙层的渐变

  const GalleryItemConfig(
      {this.itemWidth = 220,
      this.itemHeight = 300,
      this.itemRadius = 0,
      this.isShowItemTransformMask = true,
      this.itemShadows = const []});
}
