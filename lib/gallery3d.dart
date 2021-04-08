import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

int minCount = 3;

class Gallery3D extends StatefulWidget {
  final double itemWidth;
  final double itemHeight;
  final int itemCount;
  final double itemRadius;
  final IndexedWidgetBuilder itemBuilder;
  final bool autoLoop;
  final int delayTime;
  final int scrollTime;
  final Function(int) onClickItem;

  Gallery3D(
      {Key key,
      this.itemWidth = 220.0,
      this.itemHeight = 300.0,
      this.autoLoop = true,
      this.delayTime = 5000,
      this.scrollTime = 800,
      this.itemRadius = 0,
      this.onClickItem,
      @required this.itemCount,
      @required this.itemBuilder})
      : assert(itemCount >= minCount),
        super(key: key);

  @override
  _Gallery3DState createState() => _Gallery3DState();
}

class _Gallery3DState extends State<Gallery3D> with TickerProviderStateMixin {
  // var scale = 1.0;

  List<Widget> imageWidgetList = [];
  AnimationController _timerAnimationController;
  Animation _timerAnimation;
  AnimationController _autoScrollAnimationController;
  double perimeter = 0;
  Timer timer;

  Map<int, GlobalKey<_GalleryImageViewState>> globalKeyMap =
      Map<int, GlobalKey<_GalleryImageViewState>>();

  ///当前索引
  int currentIndex = -1;

  @override
  void initState() {
    _onFocusImageChanged(0, 1, false);
    if (widget.autoLoop) {
      perimeter = calculatePerimeter(widget.itemWidth * 0.8, 50);
      Timer.periodic(Duration(milliseconds: widget.delayTime), (timer) {
        this.timer = timer;
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

    super.initState();
  }

  @override
  void dispose() {
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
      height: widget.itemHeight,
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
        widgetList.add(_buildImage(forIndex, false, 180 + angle * i, angle));
      }

      forIndex--;
    }

    //处理前一个和后一个Item在Stack中的层级
    if (refresh) {
      if (direction > 0) {
        if (globalKeyMap[currentIndex].currentState.angle < 180) {
          widgetList.add(_buildImage(nextIndex, false, 180 - angle, angle));
          widgetList.add(_buildImage(preIndex, false, angle - 180, angle));
        } else {
          widgetList.add(_buildImage(preIndex, false, angle - 180, angle));
          widgetList.add(_buildImage(nextIndex, false, 180 - angle, angle));
        }
      } else {
        if (globalKeyMap[currentIndex].currentState.angle < 180) {
          widgetList.add(_buildImage(nextIndex, false, 180 - angle, angle));
          widgetList.add(_buildImage(preIndex, false, angle - 180, angle));
        } else {
          widgetList.add(_buildImage(preIndex, false, angle - 180, angle));
          widgetList.add(_buildImage(nextIndex, false, 180 - angle, angle));
        }
      }
    } else {
      widgetList.add(_buildImage(preIndex, false, angle - 180, angle));
      widgetList.add(_buildImage(nextIndex, false, 180 - angle, angle));
    }

    widgetList.add(_buildImage(currentIndex, false, 180, angle));

    imageWidgetList = widgetList;

    if (refresh) {
      setState(() {});
    }
  }

  Widget _buildImage(int index, bool isFocus, double angle, double unitAngle) {
    if (globalKeyMap[index] == null) {
      globalKeyMap[index] = GlobalKey();
    }
    return GalleryImageView(
      key: globalKeyMap[index],
      index: index,
      width: widget.itemWidth,
      height: widget.itemHeight,
      builer: widget.itemBuilder,
      radius: widget.itemRadius,
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

class GalleryImageView extends StatefulWidget {
  final double width;
  final double height;
  final double unitAngle;
  final int index;
  final IndexedWidgetBuilder builer;
  final Function(int) onClick;
  final double radius;

  final void Function(int, int) onFocusImageChanged;
  final double angle;
  GalleryImageView(
      {Key key,
      this.index,
      this.width = 200,
      this.height = 200,
      this.unitAngle,
      this.onClick,
      this.radius,
      @required this.builer,
      this.onFocusImageChanged,
      this.angle})
      : super(key: key);

  @override
  _GalleryImageViewState createState() => _GalleryImageViewState();
}

class _GalleryImageViewState extends State<GalleryImageView> {
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
    return x + (screenWidth - widget.width) / 2;
  }

  double perimeter = 0;

  ///更新偏移数据
  void updateTransform(Offset offset) {
    if (offset.dx == 0) return;
    // 需要计算出当前位移对应的夹角,再进行计算对应的x轴坐标点
    if (perimeter == 0) {
      perimeter = calculatePerimeter(widget.width * 0.8, 50);
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

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(offsetDx ?? 0, 0),
      child: Container(
        width: widget.width,
        height: widget.height,
        child: Transform.scale(
          scale: scale,
          child: InkWell(
              onTap: () => widget.onClick(widget.index),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.radius),
                child: Stack(
                  children: [
                    Container(
                        width: widget.width,
                        height: widget.height,
                        child: widget.builer(context, widget.index)),
                    Container(
                      width: widget.width,
                      height: widget.height,
                      color: Color.fromARGB(
                          100 * (1 - scale) ~/ (1 - minScale), 0, 0, 0),
                    )
                  ],
                ),
              )),
        ),
      ),
    );
  }
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
