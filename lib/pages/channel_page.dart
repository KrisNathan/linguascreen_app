import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChannelPage extends StatefulWidget {
  const ChannelPage({super.key});

  @override
  State<ChannelPage> createState() => _ChannelPageState();
}

class _ChannelPageState extends State<ChannelPage> {
  static const platform = MethodChannel('com.example.overlay_test/helper');
  int _sum = 0;

  Future<void> _getSum() async {
    try {
      final result = await platform.invokeMethod<int>('sum', <String, dynamic>{
        'a': 1,
        'b': 2
      });
      if (result != null) {
        setState(() {
          _sum = result;
        });
      }
    } on PlatformException catch(e) {
      log('Skibidi');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(children: [
      Text('1 + 2 = $_sum'),
      TextButton(onPressed: () async {
        await _getSum();
      }, child: Text('Calc')),
    ],),);
  }
}