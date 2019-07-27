import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_flutter/bean/volume.dart';
import 'package:reader_flutter/page/reader/reader_engine.dart';
import 'package:flutter/widgets.dart';
import 'dart:async';

void main() {
  Widget snapshotText(
      BuildContext context, AsyncSnapshot<List<Chapter>> snapshot) {
    print(DateTime.now());
    if (snapshot.hasData) {
      print(snapshot.data.length);
    }

    return Text(snapshot.toString(), textDirection: TextDirection.ltr);
  }

  group('Async smoke tests', () {
    /*
    testWidgets('open file', (WidgetTester tester) async {
      String filePath = '3.txt';
      String charSet = 'utf8';
      print(DateTime.now());
      List<Chapter> chapters =
          decodeText({'filePath': filePath, 'charSet': charSet});
      print(DateTime.now());
      await tester.pumpWidget(FutureBuilder<List<Chapter>>(
        future: Future<List<Chapter>>.value(chapters),
        builder: snapshotText,
      ));
    });

    
    testWidgets('FutureBuilder', (WidgetTester tester) async {
      String filePath = '3.txt';
      String charSet = 'utf8';
      print(DateTime.now());
      var _chapters =
          compute(decodeText, {'filePath': filePath, 'charSet': charSet});

      await tester.pumpWidget(FutureBuilder<List<Chapter>>(
        future: _chapters,
        builder: snapshotText,
      ));
      await eventFiring(tester);
    });
    
    testWidgets('StreamBuilder', (WidgetTester tester) async {
      

      await tester.pumpWidget(
          StreamBuilder<String>(
            stream: inputStream.transform(utf8.decoder),
            builder: snapshotText,
          ));
      await eventFiring(tester);
    });
    */
    test('isolates test', () async {
      print('start' + DateTime.now().toString());
      var res = await compute(isoTest, {'p1': '12', 'p2': '23'});
      print('end' + DateTime.now().toString());
    });

    testWidgets('isoWidget test', (WidgetTester tester) async {
      print('start' + DateTime.now().toString());
      var res = compute(isoTest, {'p1': '12', 'p2': '23'});
      print('end' + DateTime.now().toString());
      await tester.pumpWidget(FutureBuilder<List<Chapter>>(
        future: res,
        builder: snapshotText,
      ));
    });
  });
}

List<Chapter> isoTest(Map<String, String> param) {
  print('startFunc' + DateTime.now().toString());
  return null;
}

Future<void> eventFiring(WidgetTester tester) async {
  await tester.pump(Duration(seconds: 10));
}
