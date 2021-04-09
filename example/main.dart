import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_gallery_3d/gallery3d.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  var imageUrlList = [
    "https://i0.hdslb.com/bfs/manga-static/baba5ef995c6551ff44f693b80485d0027281378.jpg@360w_480h.jpg",
    "https://i0.hdslb.com/bfs/manga-static/67ffb14f8420461aa7a61ef571f3281b228aa7d1.jpg@360w_480h.jpg",
    "https://i0.hdslb.com/bfs/manga-static/214b88f3089e66053b60dc977b44eef9ff5c462c.jpg@360w_480h.jpg",
    "https://i0.hdslb.com/bfs/manga-static/b03a8ca193bdb734266a0312b6d76df641b9dbcc.jpg@360w_480h.jpg",
    "https://i0.hdslb.com/bfs/manga-static/9731396b6816ab16a1ae419e59a6826335212dc0.jpg@360w_480h.jpg",
  ];

  int currentIndex = 0;

  Widget buildGallery3D() {
    return Gallery3D(
        itemCount: imageUrlList.length,
        itemConfig: GalleryItemConfig(
            itemWidth: 220,
            itemHeight: 300,
            itemRadius: 5,
            isShowItemTransformMask: true,
            itemShadows: [
              BoxShadow(
                  color: Color(0x90000000), offset: Offset(2, 0), blurRadius: 5)
            ]),
        currentIndex: currentIndex,
        onItemChanged: (index) {
          this.currentIndex = index;
          _backgroundBlurViewKey.currentState
              .updateImageUrl(imageUrlList[index]);
        },
        onClickItem: (index) => print("currentIndex:$index"),
        itemBuilder: (context, index) {
          return Image.network(
            imageUrlList[index],
            fit: BoxFit.fill,
          );
        });
  }

  GlobalKey<_BackgrounBlurViewState> _backgroundBlurViewKey =
      GlobalKey<_BackgrounBlurViewState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              children: [
                BackgrounBlurView(
                  imageUrl: imageUrlList[currentIndex],
                  key: _backgroundBlurViewKey,
                ),
                Container(
                  child: buildGallery3D(),
                  margin: EdgeInsets.fromLTRB(0, 50, 0, 50),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class BackgrounBlurView extends StatefulWidget {
  final String imageUrl;
  BackgrounBlurView({Key key, this.imageUrl}) : super(key: key);

  @override
  _BackgrounBlurViewState createState() => _BackgrounBlurViewState();
}

class _BackgrounBlurViewState extends State<BackgrounBlurView> {
  String imageUrl;

  @override
  void initState() {
    imageUrl = widget.imageUrl;
    super.initState();
  }

  void updateImageUrl(String url) {
    this.setState(() {
      imageUrl = url;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Container(
        height: 200,
        width: MediaQuery.of(context).size.width,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
        ),
      ),
      BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            color: Colors.black.withOpacity(0.1),
            height: 200,
            width: MediaQuery.of(context).size.width,
          ))
    ]);
  }
}
