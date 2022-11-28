import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  //ignore: avoid_print
  print("handling a background message ${message.messageId}");
}

void initInfo() {
  var androidInitialize =
      const AndroidInitializationSettings('@mipmap/ic_launcher');
  var iosInitialize = const DarwinInitializationSettings(); //IOS
  var initializationsSettings =
      InitializationSettings(android: androidInitialize, iOS: iosInitialize);
  flutterLocalNotificationsPlugin.initialize(
    initializationsSettings,
    onDidReceiveNotificationResponse: ((NotificationResponse details) async {
      // ignore: avoid_print
      print(details.payload);
    }),
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );

  FirebaseMessaging.onMessage.listen((message) async {
    // ignore: avoid_print
    print("............ onMessage.................");
    // ignore: avoid_print
    print(
        "onMessage: ${message.notification?.title}/${message.notification?.body}");
    BigTextStyleInformation bigTextStyleInformation = BigTextStyleInformation(
      message.notification!.body.toString(),
      htmlFormatBigText: true,
      contentTitle: message.notification!.title.toString(),
      htmlFormatContentTitle: true,
    );
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'channel_id',
      'channel_name',
      importance: Importance.high,
      styleInformation: bigTextStyleInformation,
      priority: Priority.high,
      playSound: true,
    );
    NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: const DarwinNotificationDetails());
    await flutterLocalNotificationsPlugin.show(
      0,
      message.notification?.title,
      message.notification?.body,
      platformChannelSpecifics,
      payload: message.data['body'],
    );
  });
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // ignore: avoid_print
  print('notification(${notificationResponse.id}) action tapped: '
      '${notificationResponse.actionId} with'
      ' payload: ${notificationResponse.payload}');
  if (notificationResponse.input?.isNotEmpty ?? false) {
    // ignore: avoid_print
    print(
        'notification action tapped with input: ${notificationResponse.input}');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initInfo();
  await Firebase.initializeApp();
  await FirebaseMessaging.instance.getInitialMessage();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notification demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MainScreen(),
    );
  }
}

//MainScreen stateful
//@TODO make a structure!
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  String? _token;
  final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();

  @override
  void initState() {
    super.initState();
    requestPermission();
    fetchToken();
    initInfo();
    // ignore: avoid_print
    print("............ READY ..................");
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }

  Future<void> requestPermission() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    switch (settings.authorizationStatus) {
      case AuthorizationStatus.authorized:
        // ignore: avoid_print
        print("....... User granted permission....");
        break;
      case AuthorizationStatus.provisional:
        // ignore: avoid_print
        print("....... User granted provisional permission....");
        break;
      default:
        // ignore: avoid_print
        print("....... User denied permission....");
        break;
    }
  }

  Future<void> fetchToken() async {
    await FirebaseMessaging.instance
        .getToken()
        // ignore: avoid_print
        .then((token) => {_token = token, print("Token: $_token")});

    //save the token to Firebase live database
    String? modelInfo = Platform.isAndroid
        ? (await fetchModelInfo() as AndroidDeviceInfo).model
        : (await fetchModelInfo() as IosDeviceInfo).name;

    FirebaseDatabase.instance
        .ref("usertokens")
        .child(modelInfo!)
        .set({"token": _token});
  }

  Future<BaseDeviceInfo> fetchModelInfo() async {
    if (Platform.isAndroid) {
      return await deviceInfoPlugin.androidInfo;
    }
    if (Platform.isIOS) {
      return await deviceInfoPlugin.iosInfo;
    }
    throw Exception("Only Android or IOS is supported!");
  }
}
