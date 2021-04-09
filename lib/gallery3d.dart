import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

int minCount = 3;

class Gallery3D extends StatefulWidget {
  final int itemCount;
  final GalleryItemConfig itemConfig;
  final bool autoLoop;
  final int delayTime;
  final int scrollTime;
  final int currentIndex;
  final IndexedWidgetBuilder itemBuilder;
  final Function(int) onItemChanged;
  final Function(int) onClickItem;

  Gallery3D(
      {Key key,
      this.autoLoop = true,
      this.delayTime = 5000,
      this.scrollTime = 800,
      this.currentIndex = 0,
      this.onClickItem,
      this.onItemChanged,
      @required this.itemConfig,
      @required this.itemCount,
      @required this.itemBuilder})
      : assert(itemCount >= minCount),
        assert(itemConfig != null),
        super(key: key);

  @override
  _Gallery3DState createState() => _Gallery3DState();
}

class _Gallery3DState extends State<Gallery3D>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // var scale = 1.0;

  List<Widget> imageWidgetList = [];
  AnimationController _timerAnimationController;
  Animation _timerAnimation;
  AnimationController _autoScrollAnimationController;
  double perimeter = 0;
  Timer timer;

  Map<int, GlobalKey<_GalleryItemState>> globalKeyMap =
      Map<int, GlobalKey<_GalleryItemState>>();

  ///当前索引
  int currentIndex = -1;
  //生命周期状态,
  AppLifecycleState appLifecycleState = AppLifecycleState.resumed;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    appLifecycleState = state;
    super.didChangeAppLifecycleState(state);
  }

  @override
  void initState() {
    _onFocusImageChanged(widget.currentIndex, 1, false);
    if (widget.autoLoop) {
      perimeter = calculatePerimeter(widget.itemConfig.itemWidth * 0.8, 50);
      Timer.periodic(Duration(milliseconds: widget.delayTime), (timer) {
        this.timer = timer;
        if (appLifecycleState != AppLifecycleState.resumed) return;
        if (DateTime.now().millisecondsSinceEpoch - lastTouchMillisecond < 5000)
          return;
        if (onTouching) return;
        var animMilliseconds = widget.scrollTime * minCount ~/ widget.itemCount;
        _timerAnimationController = AnimationController(
            duration: Duration(milliseconds: animMilliseconds), vsync: this);
        _timerAnimation = Tween(
          begin: 0.0,
          end: (-perimeter / widget.itemCount).toDouble(),
        ).animate(_timerAnimationController);

        double last = 0;
        _timerAnimation.addListener(() {
          if (onTouching) return;
          var offsetX = _timerAnimation.value - last;
          globalKeyMap.forEach((key, value) {
            value.currentState.updateTransform(Offset(offsetX, 0));
          });
          last = _timerAnimation.value;
        });
        _timerAnimationController.forward();
      });
    }
    WidgetsBinding.instance.addObserver(this);

    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    if (this.timer != null) {
      this.timer.cancel();
    }
    if (_timerAnimationController != null &&
        _timerAnimationController.isAnimating) {
      _timerAnimationController.stop(canceled: true);
    }
    if (_autoScrollAnimationController != null &&
        _autoScrollAnimationController.isAnimating) {
      _autoScrollAnimationController.stop(canceled: true);
    }
    super.dispose();
  }

  var onTouching = false;
  var lastTouchMillisecond = 0;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.itemConfig.itemHeight,
      width: MediaQuery.of(context).size.width,
      child: GestureDetector(
        //按下
        onPanDown: (details) {
          onTouching = true;
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
          lastTouchMillisecond = DateTime.now().millisecondsSinceEpoch;
          var dx = details.delta.dx;
          globalKeyMap.forEach((key, value) {
            value.currentState.updateTransform(Offset(dx, 0));
          });
        },
        child: Stack(
          children: imageWidgetList,
        ),
      ),
    );
  }

  //自动滚动,在手指抬起或者cancel回调的时候调用
  void _autoScrolling() {
    var angle = globalKeyMap[currentIndex].currentState.angle;
    _autoScrollAnimationController =
        AnimationController(duration: Duration(milliseconds: 200), vsync: this);
    Animation animation;

    if (angle > 180) {
      var target = (angle - 180) / 360 * perimeter;
      animation = Tween(begin: 0.0, end: target)
          .animate(_autoScrollAnimationController);
    } else {
      var target = -(180 - angle) / 360 * perimeter;
      animation = Tween(begin: 0.0, end: target)
          .animate(_autoScrollAnimationController);
    }
    double last = 0;
    animation.addListener(() {
      var offsetX = animation.value - last;
      globalKeyMap.forEach((key, value) {
        value.currentState.updateTransform(Offset(offsetX, 0));
      });
      last = animation.value;
    });
    _autoScrollAnimationController.forward();
    _autoScrollAnimationController.addListener(() {
      if (_autoScrollAnimationController.isCompleted) {
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
    if (currentIndex == index) return;
    if (refresh) {
      widget.onItemChanged(index);
    }
    double angle = 360 / widget.itemCount;
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
        widgetList
            .add(_buildGalleryItem(forIndex, false, 180 + angle * i, angle));
      }

      forIndex--;
    }

    //处理前一个和后一个Item在Stack中的层级
    if (refresh) {
      if (direction > 0) {
        if (globalKeyMap[currentIndex].currentState.angle < 180) {
          widgetList
              .add(_buildGalleryItem(nextIndex, false, 180 - angle, angle));
          widgetList
              .add(_buildGalleryItem(preIndex, false, angle - 180, angle));
        } else {
          widgetList
              .add(_buildGalleryItem(preIndex, false, angle - 180, angle));
          widgetList
              .add(_buildGalleryItem(nextIndex, false, 180 - angle, angle));
        }
      } else {
        if (globalKeyMap[currentIndex].currentState.angle < 180) {
          widgetList
              .add(_buildGalleryItem(nextIndex, false, 180 - angle, angle));
          widgetList
              .add(_buildGalleryItem(preIndex, false, angle - 180, angle));
        } else {
          widgetList
              .add(_buildGalleryItem(preIndex, false, angle - 180, angle));
          widgetList
              .add(_buildGalleryItem(nextIndex, false, 180 - angle, angle));
        }
      }
    } else {
      widgetList.add(_buildGalleryItem(preIndex, false, angle - 180, angle));
      widgetList.add(_buildGalleryItem(nextIndex, false, 180 - angle, angle));
    }

    widgetList.add(_buildGalleryItem(currentIndex, false, 180, angle));

    imageWidgetList = widgetList;

    if (refresh) {
      setState(() {});
    }
  }

  Widget _buildGalleryItem(
      int index, bool isFocus, double angle, double unitAngle) {
    if (globalKeyMap[index] == null) {
      globalKeyMap[index] = GlobalKey();
    }
    return GalleryItem(
      key: globalKeyMap[index],
      index: index,
      builer: widget.itemBuilder,
      config: widget.itemConfig,
      onFocusImageChanged: (index, direction) =>
          _onFocusImageChanged(index, direction, true),
      onClick: (index) {
        if (widget.onClickItem != null && index == currentIndex) {
          widget.onClickItem(index);
        }
      },
      angle: angle,
      unitAngle: unitAngle,
    );
  }
}

class GalleryItem extends StatefulWidget {
  final GalleryItemConfig config;
  final double unitAngle;
  final int index;
  final IndexedWidgetBuilder builer;
  final Function(int) onClick;

  final void Function(int, int) onFocusImageChanged;
  final double angle;
  GalleryItem(
      {Key key,
      this.index,
      this.unitAngle,
      this.onClick,
      @required this.config,
      @required this.builer,
      this.onFocusImageChanged,
      this.angle})
      : super(key: key);

  @override
  _GalleryItemState createState() => _GalleryItemState();
}

class _GalleryItemState extends State<GalleryItem> {
  double offsetDx = 0;
  double scale = 1;
  double angle = 0;

  @override
  void initState() {
    super.initState();
    angle = getFinalAngle(widget.angle.toDouble());
    Future.delayed(Duration(seconds: 0), () {
      setState(() {
        this.offsetDx = calculateX(angle);
        calculateScale();
      });
    });
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

  ///计算缩放参数
  void calculateScale() {
    // print("angle:$angle");
    var tempScale = angle / 180.0;
    tempScale = 1 - (1 - tempScale) * 0.4;
    this.scale = getFinalScale(tempScale);
  }

  ///计算椭圆轨X轴的点
  double calculateX(double angle) {
    double screenWidth = MediaQuery.of(context).size.width;
    double width = screenWidth * 0.7; //椭圆宽
    double radiusOuterX = width / 2;

    double angleOuter = (2 * pi / 360) * angle;
    double x = radiusOuterX * sin(angleOuter);
    return x + (screenWidth - widget.config.itemWidth) / 2;
  }

  double perimeter = 0;

  ///更新偏移数据
  void updateTransform(Offset offset) {
    if (offset.dx == 0) return;
    // 需要计算出当前位移对应的夹角,再进行计算对应的x轴坐标点
    if (perimeter == 0) {
      perimeter = calculatePerimeter(widget.config.itemWidth * 0.8, 50);
    }

    double offsetAngle = offset.dx.abs() / perimeter * 360;
    if (offset.dx > 0) {
      angle -= offsetAngle;
    } else {
      angle += offsetAngle;
    }
    angle = getFinalAngle(angle);

    if (angle > 180 - widget.unitAngle / 2 &&
        angle < 180 + widget.unitAngle / 2) {
      widget.onFocusImageChanged(widget.index, offset.dx > 0 ? 1 : -1);
    }

    this.offsetDx = calculateX(angle);
    calculateScale();
    setState(() {});
  }

  Widget _buildItem() {
    return Container(
        width: widget.config.itemWidth,
        height: widget.config.itemHeight,
        child: widget.builer(context, widget.index));
  }

  Widget _buildMaskTransformItem(Widget child) {
    if (!widget.config.isShowItemTransformMask) return child;
    return Stack(children: [
      child,
      Container(
        width: widget.config.itemWidth,
        height: widget.config.itemHeight,
        color: Color.fromARGB(100 * (1 - scale) ~/ (1 - minScale), 0, 0, 0),
      )
    ]);
  }

  Widget _buildRadiusItem(Widget child) {
    if (widget.config.itemRadius <= 0) return child;
    return ClipRRect(
        borderRadius: BorderRadius.circular(widget.config.itemRadius),
        child: child);
  }

  Widget _buildShadowItem(Widget child) {
    if (widget.config.itemShadows == null || widget.config.itemShadows.isEmpty)
      return child;
    return Container(
        child: child,
        decoration: BoxDecoration(boxShadow: widget.config.itemShadows));
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(offsetDx ?? 0, 0),
      child: Container(
        width: widget.config.itemWidth,
        height: widget.config.itemHeight,
        child: Transform.scale(
          scale: scale,
          child: InkWell(
            onTap: () => widget.onClick(widget.index),
            child: _buildShadowItem(
                _buildRadiusItem(_buildMaskTransformItem(_buildItem()))),
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
      this.itemShadows});
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
