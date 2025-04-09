import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// -----------------------------------------------------------------
/// 1. Background Message Handler
/// -----------------------------------------------------------------
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized during background processing.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Background message received: ${message.messageId}");
}

/// -----------------------------------------------------------------
/// 2. Global Local Notifications Plugin Instance
/// -----------------------------------------------------------------
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// -----------------------------------------------------------------
/// 3. Main Function
/// -----------------------------------------------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set background message handler.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(MyApp());
}

/// -----------------------------------------------------------------
/// 4. The Top-Level App Widget
/// -----------------------------------------------------------------
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FCM Demo App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MyHomePage(title: 'Firebase Messaging Demo'),
    );
  }
}

/// -----------------------------------------------------------------
/// 5. Model for Storing Notification History
/// -----------------------------------------------------------------
class NotificationItem {
  final String title;
  final String body;
  final String type; // e.g. 'regular' or 'important'
  final DateTime receivedAt;
  NotificationItem({
    required this.title,
    required this.body,
    required this.type,
    required this.receivedAt,
  });
}

/// -----------------------------------------------------------------
/// 6. Main Home Page with FCM and Extended Functionality
/// -----------------------------------------------------------------
class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late FirebaseMessaging messaging;
  String _fcmToken = "Token not yet fetched";
  List<NotificationItem> _notificationHistory = [];

  @override
  void initState() {
    super.initState();
    _initializeFCM();
  }

  // Initialize Firebase Messaging and Local Notifications.
  void _initializeFCM() async {
    // -----------------------------
    // Configure Local Notifications
    // -----------------------------
    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initSettings =
        InitializationSettings(android: androidInitSettings);
    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onSelectNotification: _onSelectNotification,
    );

    // -----------------------------
    // Request Notification Permissions
    // -----------------------------
    messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );
    print('User granted permission: ${settings.authorizationStatus}');

    // -----------------------------
    // Get FCM Token and Subscribe to Topic
    // -----------------------------
    messaging.getToken().then((token) {
      setState(() {
        _fcmToken = token ?? "Failed to get token";
      });
      print("FCM Token: $_fcmToken");
    });
    messaging.subscribeToTopic("messaging");

    // -----------------------------
    // Listen for Foreground Messages
    // -----------------------------
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Foreground message received: ${message.messageId}");
      String notificationType = message.data['type'] ?? 'regular';
      
      // Show a local notification with characteristics based on type.
      _showLocalNotification(message, notificationType);
      
      // Store the notification in history.
      _storeNotification(message, notificationType);
      
      // Optionally, show a dialog.
      if (message.notification != null) {
        _showMessageDialog(
          message.notification!.title ?? "Notification",
          message.notification!.body ?? "",
        );
      }
    });

    // -----------------------------
    // Handle Notification Taps (Deep Linking)
    // -----------------------------
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("Notification opened: ${message.messageId}");
      _handleDeepLink(message);
    });
  }

  // Show a simple dialog with notification details.
  void _showMessageDialog(String title, String body) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK")
            )
          ],
        );
      },
    );
  }

  // Save notification details to a local history list.
  void _storeNotification(RemoteMessage message, String type) {
    final item = NotificationItem(
      title: message.notification?.title ?? "No Title",
      body: message.notification?.body ?? "No Body",
      type: type,
      receivedAt: DateTime.now(),
    );
    setState(() {
      _notificationHistory.add(item);
    });
  }

  // Display a local notification using flutter_local_notifications.
  Future<void> _showLocalNotification(RemoteMessage message, String type) async {
    RemoteNotification? notification = message.notification;
    if (notification == null) return;

    // Define channels for regular and important notifications.
    const String channelRegular = 'regular_channel';
    const String channelImportant = 'important_channel';
    
    const AndroidNotificationDetails regularDetails =
        AndroidNotificationDetails(
          channelRegular,
          'Regular Notifications',
          channelDescription: 'Channel for regular notifications',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        );
        
    const AndroidNotificationDetails importantDetails =
        AndroidNotificationDetails(
          channelImportant,
          'Important Notifications',
          channelDescription: 'Channel for important notifications with sound & vibration',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          sound: RawResourceAndroidNotificationSound('notification_sound'),
          playSound: true,
          enableVibration: true,
        );
        
    AndroidNotificationDetails chosenDetails =
        (type == 'important') ? importantDetails : regularDetails;
        
    NotificationDetails platformDetails =
        NotificationDetails(android: chosenDetails);

    // Use the data field 'deep_link' for deep linking actions.
    await flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      platformDetails,
      payload: message.data['deep_link'] ?? "",
    );
  }

  // Callback when a local notification is tapped.
  Future _onSelectNotification(String? payload) async {
    if (payload != null && payload.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DeepLinkScreen(payload: payload)),
      );
    }
  }

  // Handle deep link navigation.
  void _handleDeepLink(RemoteMessage message) {
    String payload = message.data['deep_link'] ?? "";
    if (payload.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DeepLinkScreen(payload: payload)),
      );
    }
  }

  // Build the UI: Displays FCM token and allows access to notification history.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NotificationHistoryScreen(history: _notificationHistory),
                ),
              );
            },
          )
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("FCM Token:", style: TextStyle(fontWeight: FontWeight.bold)),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(_fcmToken),
              ),
              SizedBox(height: 20),
              Text("Waiting for notifications..."),
            ],
          ),
        ),
      ),
    );
  }
}

/// -----------------------------------------------------------------
/// 7. Deep Link Screen: Opened when a notification with a deep_link is tapped.
/// -----------------------------------------------------------------
class DeepLinkScreen extends StatelessWidget {
  final String payload;
  const DeepLinkScreen({Key? key, required this.payload}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Deep Link Page")),
      body: Center(child: Text("Opened via deep link: $payload")),
    );
  }
}

/// -----------------------------------------------------------------
/// 8. Notification History Screen: List of all received notifications.
/// -----------------------------------------------------------------
class NotificationHistoryScreen extends StatelessWidget {
  final List<NotificationItem> history;
  const NotificationHistoryScreen({Key? key, required this.history}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Notification History")),
      body: history.isEmpty
          ? Center(child: Text("No notifications received yet."))
          : ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];
                return ListTile(
                  title: Text(item.title),
                  subtitle: Text(item.body),
                  trailing: Text(item.type),
                );
              },
            ),
    );
  }
}
