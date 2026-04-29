import 'package:flutter/material.dart';

class Globals {
  static final Globals _instance = Globals._internal();
  factory Globals() => _instance;
  Globals._internal();

  ValueNotifier<int> projectTab = ValueNotifier<int>(0);
}