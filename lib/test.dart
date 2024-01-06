import 'dart:async';

import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

void main() => runApp(const MyHomePage());

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.blueGrey,
        body: SafeArea(
          child: Center(
            child: BiggerView(
              config: BiggerConfig(
                  image: const AssetImage("images/img_1769.jpg"),
                  rate: 3,
                  isClip: true),
            ),
          ),
        ),
      ),
    );
  }
}

class ImageLoader {
  ImageLoader._(); //私有化构造
  static final ImageLoader loader = ImageLoader._(); //单例模式

//通过[Uint8List]获取图片,默认宽高[width][height]
  Future<ui.Image> loadImageByUint8List(
    Uint8List list, {
    required int width,
    required int height,
  }) async {
    ui.Codec codec = await ui.instantiateImageCodec(list,
        targetWidth: width, targetHeight: height);
    ui.FrameInfo frame = await codec.getNextFrame();
    return frame.image;
  }

  //通过ImageProvider读取Image
  Future<ui.Image> loadImageByProvider(
    ImageProvider provider, {
    ImageConfiguration config = ImageConfiguration.empty,
  }) async {
    Completer<ui.Image> completer = Completer<ui.Image>(); //完成的回调
    late ImageStreamListener listener;
    ImageStream stream = provider.resolve(config); //获取图片流
    listener = ImageStreamListener((ImageInfo frame, bool sync) {
      //监听
      final ui.Image image = frame.image;
      completer.complete(image); //完成
      stream.removeListener(listener); //移除监听
    });
    stream.addListener(listener); //添加监听
    return completer.future; //返回
  }
}

class BiggerConfig {
  double rate;
  ImageProvider image;
  double radius;
  Color outlineColor;
  bool isClip;

  BiggerConfig(
      {this.rate = 3,
      required this.image,
      this.isClip = true,
      this.radius = 30,
      this.outlineColor = Colors.white});
}

class BiggerView extends StatefulWidget {
  const BiggerView({
    super.key,
    required this.config,
  });

  final BiggerConfig config;

  @override
  _BiggerViewState createState() => _BiggerViewState();
}

class _BiggerViewState extends State<BiggerView> {
  var posX = 0.0;
  var posY = 0.0;
  bool canDraw = false;
  var width = 0.0;
  var height = 0.0;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ui.Image>(
      future: ImageLoader.loader.loadImageByProvider(widget.config.image),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          width = (snapshot.data!.width.toDouble() / widget.config.rate)!;
          height = (snapshot.data!.height.toDouble() / widget.config.rate)!;
        }

        return GestureDetector(
          onPanDown: (detail) {
            posX = detail.localPosition.dx;
            posY = detail.localPosition.dy;
            canDraw = true;
            setState(() {});
          },
          onPanUpdate: (detail) {
            posX = detail.localPosition.dx;
            posY = detail.localPosition.dy;
            if (judgeRectArea(posX, posY, width + 2, height + 2)) {
              setState(() {});
            }
          },
          onPanEnd: (detail) {
            canDraw = false;
            setState(() {});
          },
          child: Container(
            width: width,
            height: height,
            child: CustomPaint(
              painter: BiggerPainter(
                  snapshot.data,
                  posX,
                  posY,
                  canDraw,
                  widget.config.radius,
                  widget.config.rate,
                  widget.config.isClip),
            ),
          ),
        );
      },
    );
  }

  //判断落点是否在矩形区域
  bool judgeRectArea(double dstX, double dstY, double w, double h) {
    return (dstX - w / 2).abs() < w / 2 && (dstY - h / 2).abs() < h / 2;
  }
}

class BiggerPainter extends CustomPainter {
  ui.Image? _img; //图片
  Paint? mainPaint; //主画笔
  Path? circlePath; //圆路径
  double _x; //触点x
  double _y; //触点y
  double _radius; //圆形放大区域
  double _rate; //放大倍率
  bool _canDraw; //是否绘制放大图
  bool _isClip; //是否是裁切模式
  BiggerPainter(this._img, this._x, this._y, this._canDraw, this._radius,
      this._rate, this._isClip) {
    mainPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    circlePath = Path();
  }

  @override
  void paint(Canvas canvas, Size size) {
    Rect rect = Offset.zero & size;
    canvas.clipRect(rect); //裁剪区域
    final _img = this._img;
    if (_img != null) {
      Rect src =
          Rect.fromLTRB(0, 0, _img.width.toDouble(), _img.height.toDouble());
      canvas.drawImageRect(_img, src, rect, mainPaint!);
      if (_canDraw) {
        var tempY = _y;
        _y = _y > 2 * _radius ? _y - 2 * _radius : _y + _radius;
        circlePath
            ?.addOval(Rect.fromCircle(center: Offset(_x, _y), radius: _radius));
        if (_isClip) {
          canvas.clipPath(circlePath!);
          canvas.drawImage(_img,
              Offset(-_x * (_rate - 1), -tempY * (_rate - 1)), mainPaint!);
          canvas.drawPath(circlePath!, mainPaint!);
        } else {
          canvas.drawImage(_img,
              Offset(-_x * (_rate - 1), -tempY * (_rate - 1)), mainPaint!);
        }
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

/// 测试
var showBiggerView = Center(
  child: BiggerView(
    config: BiggerConfig(
        image: const AssetImage("images/test.png"), rate: 3, isClip: true),
  ),
);

// class ImagePage extends StatefulWidget {
//   @override
//   _ImagePageState createState() => _ImagePageState();
// }
//
// class _ImagePageState extends State<ImagePage> {
//   ui.Image? _image;
//
//   /// 初始化照片
//   @override
//   void initState() {
//     super.initState();
//     _asyncInit();
//   }
//
//   Future<void> _asyncInit() async {
//     // 加载资源文件
//     final data = await rootBundle.load("images/test.png");
//     // 把资源文件转换成Uint8List类型
//     final bytes = data.buffer.asUint8List();
//     // 解析Uint8List类型的数据图片
//     final image = await decodeImageFromList(bytes);
//     _image = image;
//     setState(() {});
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       child: CustomPaint(
//         painter: ImagePainter(image: _image!),
//       ),
//     );
//   }
// }
//
// class ImagePainter extends CustomPainter {
//   ui.Image? image;
//   Paint? mainPaint;
//   ImagePainter({required this.image}) {
//     mainPaint = Paint()..isAntiAlias = true;
//   }
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     canvas.drawImage(
//         image!, //报错
//         const Offset(0, 0),
//         mainPaint!);
//   }
//
//   @override
//   bool shouldRepaint(CustomPainter oldDelegate) {
//     // TODO: implement shouldRepaint
//     return true;
//   }
// }
