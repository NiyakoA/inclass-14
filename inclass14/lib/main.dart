import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Global instance for local notifications.
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Top-level function to handle background notification responses.
/// This is required for proper background handling on some platforms.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint('Background notification tapped with payload: ${notificationResponse.payload}');
}

/// Top-level function to handle background FCM messages.
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Register the FCM background handler.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FCM Demo App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Firebase Messaging Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  MyHomePage({Key? key, required this.title}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late FirebaseMessaging messaging;
  String? _fcmToken;

  @override
  void initState() {
    super.initState();
    _initializeLocalNotifications();
    _initializeFirebaseMessaging();
  }

  /// Initializes the flutter_local_notifications plugin using the new callbacks.
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
        InitializationSettings(android: androidInitSettings);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _handleNotificationTap(payload);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  }

  /// Configures Firebase Messaging.
  void _initializeFirebaseMessaging() {
    messaging = FirebaseMessaging.instance;

    // Retrieve the FCM token and store it.
    messaging.getToken().then((token) {
      setState(() {
        _fcmToken = token;
      });
      debugPrint("FCM Token: $token");
    });

    // Optionally subscribe to a topic.
    messaging.subscribeToTopic("messaging");

    // Handle foreground messages.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground message received: ${message.messageId}');
      if (message.notification != null) {
        _showForegroundDialog(
          message.notification!.title ?? "Notification",
          message.notification!.body ?? ""
        );
      }
    });

    // Handle when a user taps on a notification to open the app.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification opened: ${message.messageId}');
      final deepLink = message.data['deep_link'] ?? "";
      if (deepLink.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DeepLinkScreen(payload: deepLink))
        );
      }
    });
  }

  /// Called when a notification is tapped.
  void _handleNotificationTap(String payload) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DeepLinkScreen(payload: payload))
    );
  }

  /// Displays an AlertDialog when a message is received in the foreground.
  void _showForegroundDialog(String title, String body) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              child: const Text("OK"),
              onPressed: () => Navigator.of(context).pop(),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Messaging Tutorial'),
            const SizedBox(height: 20),
            if (_fcmToken != null) Text('FCM Token: $_fcmToken'),
          ],
        ),
      ),
    );
  }
}

/// Simple screen to display payload information when a deep link is tapped.
class DeepLinkScreen extends StatelessWidget {
  final String payload;
  const DeepLinkScreen({Key? key, required this.payload}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deep Link Screen'),
      ),
      body: Center(
        child: Text('Payload: $payload'),
      ),
    );
  }
}
