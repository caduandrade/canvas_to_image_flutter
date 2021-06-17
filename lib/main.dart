import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

void main() {
  runApp(CanvasToImageApp());
}

class CanvasToImageApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Canvas to Image',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false,
      home: CanvasToImagePage(),
    );
  }
}

class CanvasToImagePage extends StatefulWidget {
  @override
  _CanvasToImagePageState createState() => _CanvasToImagePageState();
}

enum _BufferType { off, picture, image, imageProvider }

enum BufferSource { pictureRecorder, repaintBoundary }

class _CanvasToImagePageState extends State<CanvasToImagePage> {
  final Size _size = Size(500, 300);
  final GlobalKey _repaintKey = GlobalKey();

  _BufferType _bufferType = _BufferType.off;
  BufferSource? _bufferSource;

  bool _bufferLoading = false;

  // buffers
  ui.Picture? _picture;
  ui.Image? _image;
  ImageProvider? _imageProvider;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Row(children: [
      _buildMenu(),
      Expanded(
          child: Center(
              child: Container(
                  child: _buildCanvas(),
                  decoration: BoxDecoration(border: Border.all()),
                  width: _size.width,
                  height: _size.height)))
    ], crossAxisAlignment: CrossAxisAlignment.stretch));
  }

  Widget _buildMenu() {
    List<Widget> children = [
      Padding(child: Text('Buffer:'), padding: EdgeInsets.only(bottom: 16)),
      _buildBufferTypeButton('Off', _BufferType.off),
      _buildBufferTypeButton('Picture', _BufferType.picture),
      _buildBufferTypeButton('Image', _BufferType.image),
      _buildBufferTypeButton('ImageProvider', _BufferType.imageProvider)
    ];
    List<BufferSource> bufferSources = getBufferSources(_bufferType);
    if (bufferSources.isNotEmpty) {
      children.add(Padding(
          child: Text('Source:'),
          padding: EdgeInsets.only(top: 16, bottom: 16)));
      for (BufferSource bufferSource in bufferSources) {
        children.add(_buildBufferSourceButton(bufferSource));
      }
    }
    return Container(
        child: Column(
          children: children,
        ),
        padding: EdgeInsets.all(16));
  }

  Widget _buildBufferTypeButton(String text, _BufferType bufferType) {
    TextButton textButton = TextButton(
        onPressed: () {
          if (!_bufferLoading) {
            setState(() {
              _bufferType = bufferType;
              _bufferSource = getDefaultBufferSource(bufferType);
              _picture = null;
              _image = null;
              _imageProvider = null;
            });
          }
        },
        child: Text(text));
    Color? color = Colors.transparent;
    if (_bufferType == bufferType) {
      color = Colors.blue;
    }
    return Container(
        child: textButton,
        decoration: BoxDecoration(border: Border.all(color: color)),
        padding: EdgeInsets.fromLTRB(8, 0, 8, 0));
  }

  Widget _buildBufferSourceButton(BufferSource bufferSource) {
    TextButton textButton = TextButton(
        onPressed: () {
          if (!_bufferLoading) {
            setState(() {
              _bufferSource = bufferSource;
              _picture = null;
              _image = null;
              _imageProvider = null;
            });
          }
        },
        child: Text(bufferSource.toString().split('.').last));
    Color? color = Colors.transparent;
    if (_bufferSource == bufferSource) {
      color = Colors.blue;
    }
    return Container(
        child: textButton,
        decoration: BoxDecoration(border: Border.all(color: color)),
        padding: EdgeInsets.fromLTRB(8, 0, 8, 0));
  }

  List<BufferSource> getBufferSources(_BufferType bufferType) {
    switch (bufferType) {
      case _BufferType.picture:
        return [BufferSource.pictureRecorder];
      case _BufferType.image:
        return [BufferSource.pictureRecorder, BufferSource.repaintBoundary];
      case _BufferType.imageProvider:
        return [BufferSource.pictureRecorder, BufferSource.repaintBoundary];
      default:
        return [];
    }
  }

  BufferSource? getDefaultBufferSource(_BufferType bufferType) {
    List<BufferSource> sources = getBufferSources(bufferType);
    return sources.isNotEmpty ? sources.first : null;
  }

  Widget _buildCanvas() {
    if (_bufferType == _BufferType.off) {
      return CustomPaint(painter: _Painter(), child: Container());
    } else {
      if (_picture != null) {
        return CustomPaint(
            painter: _BufferPainter(picture: _picture), child: Container());
      } else if (_image != null) {
        return CustomPaint(
            painter: _BufferPainter(image: _image), child: Container());
      } else if (_imageProvider != null) {
        return Image(
            image: _imageProvider!,
            isAntiAlias: true,
            filterQuality: FilterQuality.high);
      }
      _scheduleBufferLoad();
      if (_bufferSource == BufferSource.repaintBoundary) {
        return RepaintBoundary(
            key: _repaintKey,
            child: CustomPaint(painter: _Painter(), child: Container()));
      }
      return Text('Loading...');
    }
  }

  _scheduleBufferLoad() {
    if (!_bufferLoading) {
      // running out of build
      Future.delayed(Duration.zero, () {
        setState(() {
          _bufferLoading = true;
        });
        if (_bufferType == _BufferType.picture) {
          _loadPicture().then((value) {
            setState(() {
              _picture = value;
              _bufferLoading = false;
            });
          });
        } else if (_bufferType == _BufferType.image &&
            _bufferSource == BufferSource.pictureRecorder) {
          _loadImageFromPictureRecorder().then((value) {
            setState(() {
              _image = value;
              _bufferLoading = false;
            });
          });
        } else if (_bufferType == _BufferType.image &&
            _bufferSource == BufferSource.repaintBoundary) {
          _loadImageFromRepaintBoundary().then((value) {
            setState(() {
              _image = value;
              _bufferLoading = false;
            });
          });
        } else if (_bufferType == _BufferType.imageProvider &&
            _bufferSource == BufferSource.pictureRecorder) {
          _loadImageProviderFromPictureRecorder().then((value) {
            setState(() {
              _imageProvider = value;
              _bufferLoading = false;
            });
          });
        } else if (_bufferType == _BufferType.imageProvider &&
            _bufferSource == BufferSource.repaintBoundary) {
          _loadImageProviderFromRepaintBoundary().then((value) {
            setState(() {
              _imageProvider = value;
              _bufferLoading = false;
            });
          });
        }
      });
    }
  }

  Future<ui.Picture> _loadPicture() async {
    ui.PictureRecorder recorder = ui.PictureRecorder();
    Canvas canvas = Canvas(recorder,
        Rect.fromPoints(Offset.zero, Offset(_size.width, _size.height)));

    _Painter painter = _Painter();
    painter.paint(canvas, _size);

    ui.Picture picture = recorder.endRecording();
    return picture;
  }

  Future<ui.Image> _loadImageFromPictureRecorder() async {
    ui.Picture picture = await _loadPicture();
    return await picture.toImage(_size.width.ceil(), _size.height.ceil());
  }

  Future<MemoryImage> _loadImageProviderFromPictureRecorder() async {
    ui.Image image = await _loadImageFromPictureRecorder();
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return MemoryImage(byteData!.buffer.asUint8List());
  }

  Future<ui.Image> _loadImageFromRepaintBoundary() async {
    RenderRepaintBoundary boundary =
        _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary;
    return await boundary.toImage();
  }

  Future<MemoryImage> _loadImageProviderFromRepaintBoundary() async {
    ui.Image image = await _loadImageFromRepaintBoundary();
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return MemoryImage(byteData!.buffer.asUint8List());
  }
}

class _Painter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.red
      ..isAntiAlias = true;
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
    canvas.drawLine(
        Offset(size.width / 2, 0), Offset(size.width / 2, size.height), paint);
    canvas.drawLine(
        Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
    canvas.drawCircle(
        Offset(3 * size.width / 4, size.height / 4), size.width / 10, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class _BufferPainter extends CustomPainter {
  _BufferPainter({this.image, this.picture});

  final ui.Image? image;
  final ui.Picture? picture;

  @override
  void paint(Canvas canvas, Size size) {
    if (image != null) {
      canvas.drawImage(image!, Offset.zero, Paint());
    } else if (picture != null) {
      canvas.drawPicture(picture!);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
