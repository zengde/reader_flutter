package com.luyucheng.reader_flutter;

import androidx.annotation.Nullable;

import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;

import io.flutter.app.FlutterActivity;
import io.flutter.plugin.common.MethodChannel;

public class ReadActivity extends FlutterActivity {
  private static final String CHANNEL = "zengde.github.com/file";

  @Override
  protected void onCreate(Bundle savedInstanceState) {

    super.onCreate(savedInstanceState);

    Intent intent=getIntent();
    String action=intent.getAction();
    if(action.equals(Intent.ACTION_VIEW)){
      Uri uri=intent.getData();
      String path=Uri.decode(uri.getEncodedPath());
      methodChannelFunction(path);
    }
  }

  private void methodChannelFunction(String path) {
    MethodChannel channel = new MethodChannel(getFlutterView(), CHANNEL);

    channel.invokeMethod("readLocal", path, new MethodChannel.Result() {
      @Override
      public void success(@Nullable Object o) {
        Log.i("flutter", "1.原生调用invokeFlutterMethod-success:" + o.toString());
      }

      @Override
      public void error(String s, @Nullable String s1, @Nullable Object o) {
        Log.i("flutter", "1.原生调用invokeFlutterMethod-error");
      }

      @Override
      public void notImplemented() {
        Log.i("flutter", "1.原生调用invokeFlutterMethod-notImplemented");
      }
    });
  }
}
