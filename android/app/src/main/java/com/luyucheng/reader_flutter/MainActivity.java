package com.luyucheng.reader_flutter;

import android.Manifest;
import android.annotation.SuppressLint;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.RandomAccessFile;

import io.flutter.app.FlutterActivity;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

public class MainActivity extends FlutterActivity {
  private static final String CHANNEL = "zengde.github.com/file";
  private final static int BUFFER_SIZE = 512 * 1024;
  private final static int PERMISSION_REQUEST_CODE = 1;
  private MethodChannel mMethodChannel;
  private String filePath;

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    GeneratedPluginRegistrant.registerWith(this);

    methodChannelFunction();
  }

  private void methodChannelFunction() {
    mMethodChannel = new MethodChannel(getFlutterView(), CHANNEL);

    mMethodChannel.setMethodCallHandler((call, result) -> {
      if (call.method.equals("readFile")) {
        final String path = call.argument("path");
        String content = readFile(path);
        result.success(content);
      } else if (call.method.equals("writeFile")) {
        final String path = call.argument("path");
        filePath = path;
        requestPermission();
      } else {
        result.notImplemented();
      }
    });
  }

  @SuppressLint("NewApi")
  private boolean requestPermission() {
    String[] permission = { Manifest.permission.READ_EXTERNAL_STORAGE, Manifest.permission.WRITE_EXTERNAL_STORAGE };
    if (Build.VERSION.SDK_INT > Build.VERSION_CODES.LOLLIPOP) {
      if (checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
        requestPermissions(permission, PERMISSION_REQUEST_CODE);
      }
    }
    return true;
  }

  @Override
  public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
    super.onRequestPermissionsResult(requestCode, permissions, grantResults);
    if (requestCode == PERMISSION_REQUEST_CODE) {
      for (int i = 0; i < permissions.length; i++) {
        if (permissions[i].equals(Manifest.permission.WRITE_EXTERNAL_STORAGE) && grantResults[i] == 0) {
          new Handler(Looper.myLooper()).post(() -> {
            int res = writeFile(filePath);
            mMethodChannel.invokeMethod("finishFile", res);
          });
        }
      }
    }
  }

  public String readFile(String path) {
    File mBookFile = new File(path);
    byte[] buffer = new byte[BUFFER_SIZE];
    int length;
    String content = "";
    try (RandomAccessFile bookStream = new RandomAccessFile(mBookFile, "r")) {

      while ((length = bookStream.read(buffer, 0, buffer.length)) > 0) {
        content += new String(buffer, 0, length, "gbk");
      }
    } catch (FileNotFoundException e) {
      e.printStackTrace();
    } catch (IOException e) {
      e.printStackTrace();
    }
    System.gc();
    System.runFinalization();
    return content;
  }

  public int writeFile(String path) {
    File destFile = new File(path + ".utf8");
    File mBookFile = new File(path);
    byte[] buffer = new byte[BUFFER_SIZE];
    int length;
    int result = 0;
    int filelength = 0;
    try (RandomAccessFile bookStream = new RandomAccessFile(mBookFile, "r");
        RandomAccessFile outputStream = new RandomAccessFile(destFile, "rw")) {

      while ((length = bookStream.read(buffer, 0, buffer.length)) > 0) {
        String blockContent = new String(buffer, 0, length, "gbk");
        outputStream.seek(filelength);
        outputStream.writeBytes(blockContent);
        filelength += length;
      }
      result = 1;

    } catch (FileNotFoundException e) {
      e.printStackTrace();
    } catch (IOException e) {
      e.printStackTrace();
    }
    System.gc();
    System.runFinalization();
    return result;

  }
}
