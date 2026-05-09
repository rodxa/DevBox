import 'package:flutter/material.dart';
import 'dart:io';

class Globals {
  static final Globals _instance = Globals._internal();
  factory Globals() => _instance;
  Globals._internal();

  ValueNotifier<int> projectTab = ValueNotifier<int>(0);
  Directory? currentProjectFolder;
}