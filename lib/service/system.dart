import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart' show required;
import 'package:permission_handler/permission_handler.dart';
import 'package:reader_flutter/service/book.dart';
import 'file.dart';

class SystemService {
  static SystemService _cache;

  SystemService._internal()
      : _streamController = new StreamController<dynamic>.broadcast();

  factory SystemService() {
    if (null == _cache) {
      print('initiate SystemService');
      _cache = new SystemService._internal();
    } else {
      print('SystemService initiated already');
    }
    return _cache;
  }

  /// controller of stream
  final StreamController<dynamic> _streamController;

  /// get a [Stream]
  Stream get _stream => _streamController.stream;

  /// fire a event
  /// value = [String eventName, dynamic data]
  void send(value) => _streamController.add(value);

  /// add listener and return [StreamSubscription]
  StreamSubscription<T> listen<T>(void onData(T event)) {
    return _stream.listen(onData);
  }

  /// device's platform
  bool get isAndroid => Platform.isAndroid;

  bool get isIOS => Platform.isIOS;

  bool get isFuchsia => Platform.isFuchsia;

  /// Check a [permission] and return a [Future] with the result
  Future<bool> checkPermission(PermissionGroup permission) {
    Future<PermissionStatus> permissionStatus =
        PermissionHandler().checkPermissionStatus(permission);
    return permissionStatus
        .then((PermissionStatus result) => result == PermissionStatus.granted);
  }

  /// Request a [permission] and return a [Future] with the result
  Future<bool> requestPermission(PermissionGroup permission) {
    List<PermissionGroup> permissions = <PermissionGroup>[permission];
    Future<Map<PermissionGroup, PermissionStatus>> requestFuture =
        PermissionHandler().requestPermissions(permissions);
    return requestFuture.then(
        (Map<PermissionGroup, PermissionStatus> permissionRequestResult) =>
            permissionRequestResult[permission] == PermissionStatus.granted);
  }

  /// Open app settings on Android and iOs
  Future<bool> openSettings() => PermissionHandler().openAppSettings();

  /// Get iOs permission status
  Future<PermissionStatus> getPermissionStatus(PermissionGroup permission) =>
      PermissionHandler().checkPermissionStatus(permission);

  FileService _fileService;

  FileService get fileService {
    if (null == _fileService) {
      _fileService = new FileService();
    }
    return _fileService;
  }

  BookService _bookService;

  BookService get bookService {
    if (null == _bookService) {
      _bookService = new BookService();
    }
    return _bookService;
  }
}
