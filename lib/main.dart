import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    const cupertinoThemeData = CupertinoThemeData();
    var row = Row(children: const <Widget>[
      Center(child: MyHomePage(title: 'Flutter Texture Demo Home')),
      Center(child: MyHomePage(title: 'Flutter Texture Demo Home')),
      Center(child: MyHomePage(title: 'Flutter Texture Demo Home')),
    ]);

    return CupertinoApp(
        title: 'Flutter Texture Demo',
        theme: cupertinoThemeData,
        home: CupertinoTheme(data: cupertinoThemeData, child: row));
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const MethodChannel _channel = MethodChannel('opengl_texture');
  int? _textureId;

  @override
  void initState() {
    log("MyHomePageState::initState");
    initTextureId();
    super.initState();
  }

  Future<void> initTextureId() async {
    var value = await _channel.invokeMethod("get_texture_id");
    log("MyHomePageState::get_texture_id_callback $value");
    setState(() {
      _textureId = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    var tid = _textureId;

    if (tid == null) {
      return const Text("Loading...", style: TextStyle(color: Colors.white));
    } else {
      return SizedBox(
        child: Texture(textureId: tid),
        width: 200,
        height: 200,
      );
    }
  }
}
