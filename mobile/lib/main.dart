// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'config/app_theme.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/site_settings_provider.dart';
import 'providers/theme_provider.dart';
import 'models/item_model.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/item_detail_screen.dart';
import 'screens/add_item_screen.dart';
import 'screens/edit_item_screen.dart';
import 'screens/my_items_screen.dart';
import 'screens/my_orders_screen.dart';
import 'screens/my_reservations_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/wishlist_screen.dart';
import 'screens/chat_inbox_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/support_hub_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/activity_history_screen.dart';
import 'screens/legal_detail_screen.dart';
import 'screens/site_info_screen.dart';
import 'screens/support_form_screen.dart';
import 'screens/support_tickets_screen.dart';
import 'services/app_navigation_service.dart';
import 'services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache.maximumSize = 100;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 60 << 20;

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await PushNotificationService.instance.initialize();

  // Load saved user
  final authProvider = AuthProvider();
  await authProvider.loadUser();
  final themeProvider = ThemeProvider();
  await themeProvider.loadPreference();
  final siteSettingsProvider = SiteSettingsProvider();
  await siteSettingsProvider.loadSettings();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: siteSettingsProvider),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
      ],
      child: const CampusMartApp(),
    ),
  );
}

class CampusMartApp extends StatelessWidget {
  const CampusMartApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'Campus Mart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: appScaffoldMessengerKey,

      // Initial route
      initialRoute: '/',

      // Route generator (for passing arguments)
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const HomeScreen());

          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());

          case '/register':
            return MaterialPageRoute(builder: (_) => const RegisterScreen());

          case '/forgot-password':
            return MaterialPageRoute(
                builder: (_) => const ForgotPasswordScreen());

          case '/item':
            final id = settings.arguments as int;
            return MaterialPageRoute(
                builder: (_) => ItemDetailScreen(itemId: id));

          case '/add-item':
            return MaterialPageRoute(
              builder: (context) =>
                  _buildProtectedScreen(context, const AddItemScreen()),
            );

          case '/my-items':
            return MaterialPageRoute(
              builder: (context) =>
                  _buildProtectedScreen(context, const MyItemsScreen()),
            );

          case '/my-orders':
            return MaterialPageRoute(
              builder: (context) =>
                  _buildProtectedScreen(context, const MyOrdersScreen()),
            );

          case '/orders':
            return MaterialPageRoute(
              builder: (context) =>
                  _buildProtectedScreen(context, const MyOrdersScreen()),
            );

          case '/wishlist':
            return MaterialPageRoute(
              builder: (context) =>
                  _buildProtectedScreen(context, const WishlistScreen()),
            );

          case '/reservations':
            return MaterialPageRoute(
              builder: (context) => _buildProtectedScreen(
                context,
                const MyReservationsScreen(),
              ),
            );

          case '/edit-item':
            final item = settings.arguments as Item;
            return MaterialPageRoute(
              builder: (context) => _buildProtectedScreen(
                context,
                EditItemScreen(item: item),
              ),
            );

          case '/profile':
            return MaterialPageRoute(
              builder: (context) =>
                  _buildProtectedScreen(context, const ProfileScreen()),
            );

          case '/admin':
            return MaterialPageRoute(
              builder: (context) =>
                  _buildAdminScreen(context, const AdminScreen()),
            );

          case '/support':
            return MaterialPageRoute(builder: (_) => const SupportHubScreen());

          case '/about':
            return MaterialPageRoute(
              builder: (_) => _buildAboutScreen(),
            );

          case '/contact':
            return MaterialPageRoute(
              builder: (_) => const SupportFormScreen(
                mode: SupportFormMode.contact,
              ),
            );

          case '/help':
            return MaterialPageRoute(
              builder: (_) => _buildHelpCenterScreen(),
            );

          case '/faq':
            return MaterialPageRoute(
              builder: (_) => _buildFaqScreen(),
            );

          case '/feedback':
            return MaterialPageRoute(
              builder: (_) => const SupportFormScreen(
                mode: SupportFormMode.feedback,
              ),
            );

          case '/report-problem':
            return MaterialPageRoute(
              builder: (_) => const SupportFormScreen(
                mode: SupportFormMode.problem,
              ),
            );

          case '/community-guidelines':
            return MaterialPageRoute(
              builder: (_) => _buildCommunityGuidelinesScreen(),
            );

          case '/settings':
            return MaterialPageRoute(
              builder: (context) =>
                  _buildProtectedScreen(context, const SettingsScreen()),
            );

          case '/notifications':
            return MaterialPageRoute(
              builder: (context) => _buildProtectedScreen(
                context,
                const NotificationsScreen(),
              ),
            );

          case '/activity':
            return MaterialPageRoute(
              builder: (context) => _buildProtectedScreen(
                context,
                const ActivityHistoryScreen(),
              ),
            );

          case '/support-tickets':
            return MaterialPageRoute(
              builder: (context) => _buildProtectedScreen(
                context,
                const SupportTicketsScreen(),
              ),
            );

          case '/legal':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => LegalDetailScreen(
                title: args['title'] as String,
                intro: args['intro'] as String,
                sections:
                    List<Map<String, String>>.from(args['sections'] as List),
              ),
            );

          case '/privacy-policy':
            return MaterialPageRoute(
              builder: (_) => _buildLegalScreen(
                title: 'Privacy Policy',
                intro:
                    'We store account, listing, support, and transaction data only for product operations and safety.',
                sections: const [
                  {
                    'title': 'Information We Collect',
                    'body':
                        'Account details, listing content, transaction metadata, support requests, reports, and notification tokens where enabled.',
                  },
                  {
                    'title': 'Why We Use It',
                    'body':
                        'To run listings, secure access, enable communication, detect abuse, and improve product safety.',
                  },
                ],
              ),
            );

          case '/terms-and-conditions':
            return MaterialPageRoute(
              builder: (_) => _buildLegalScreen(
                title: 'Terms & Conditions',
                intro:
                    'Fake listings, abuse, impersonation, and unsafe marketplace behavior are not allowed.',
                sections: const [
                  {
                    'title': 'Marketplace Conduct',
                    'body':
                        'Users must not post fake, stolen, or misleading listings and must avoid harassment, spam, and fraud.',
                  },
                  {
                    'title': 'Moderation Rights',
                    'body':
                        'Campus Mart may review, hide, or remove listings and suspend accounts to protect the community.',
                  },
                ],
              ),
            );

          case '/refund-policy':
            return MaterialPageRoute(
              builder: (_) => _buildLegalScreen(
                title: 'Refund Policy',
                intro:
                    'Refunds depend on payment state, dispute review, and delivery evidence.',
                sections: const [
                  {
                    'title': 'When refunds may apply',
                    'body':
                        'Duplicate payments, failed delivery, fraud indicators, or approved disputes can qualify.',
                  },
                  {
                    'title': 'Review process',
                    'body':
                        'Support and admin teams review payment timeline, user actions, and issue evidence before deciding.',
                  },
                ],
              ),
            );

          case '/cookie-policy':
            return MaterialPageRoute(
              builder: (_) => _buildLegalScreen(
                title: 'Cookie Policy',
                intro:
                    'Campus Mart stores lightweight session and preference data for smoother product behavior.',
                sections: const [
                  {
                    'title': 'Stored data',
                    'body':
                        'Login session, language, notifications, and product preferences may be cached locally.',
                  },
                  {
                    'title': 'Your control',
                    'body':
                        'You can log out, clear storage, or change product settings anytime.',
                  },
                ],
              ),
            );

          case '/disclaimer':
            return MaterialPageRoute(
              builder: (_) => _buildLegalScreen(
                title: 'Disclaimer',
                intro:
                    'The marketplace helps students discover items and communicate, but does not guarantee every listing or meetup outcome.',
                sections: const [
                  {
                    'title': 'Seller responsibility',
                    'body':
                        'Sellers must post truthful, lawful, and accurate listings.',
                  },
                  {
                    'title': 'Buyer responsibility',
                    'body':
                        'Buyers should verify condition, price, and safety before completing a transaction.',
                  },
                ],
              ),
            );

          case '/chat':
            return MaterialPageRoute(
              builder: (context) =>
                  _buildProtectedScreen(context, const ChatInboxScreen()),
            );

          case '/chat-room':
          case '/chat/room':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (context) => _buildProtectedScreen(
                context,
                ChatScreen(
                  otherUserId: args['otherUserId'],
                  otherUserName: args['otherUserName'],
                  otherUserPic: args['otherUserPic'],
                  itemId: args['itemId'],
                  itemTitle: args['itemTitle'],
                ),
              ),
            );

          default:
            return MaterialPageRoute(builder: (_) => const HomeScreen());
        }
      },
    );
  }
}

Widget _buildProtectedScreen(BuildContext context, Widget child) {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  return authProvider.isLoggedIn ? child : const LoginScreen();
}

Widget _buildAdminScreen(BuildContext context, Widget child) {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  if (!authProvider.isLoggedIn) {
    return const LoginScreen();
  }
  return authProvider.isAdmin ? child : const HomeScreen();
}

Widget _buildLegalScreen({
  required String title,
  required String intro,
  required List<Map<String, String>> sections,
}) {
  return LegalDetailScreen(
    title: title,
    intro: intro,
    sections: sections,
  );
}

Widget _buildAboutScreen() {
  return const SiteInfoScreen(
    eyebrow: 'About Campus Mart',
    title: 'Built for student commerce, not generic classifieds.',
    description:
        'Campus Mart helps students buy, sell, reserve, review, chat, and complete safer campus deals with admin moderation and support in place.',
    sections: [
      SiteInfoSection(
        title: 'What We Solve',
        body:
            'Fast resale for books, electronics, hostel essentials, cycles, and more without noisy public marketplace friction.',
      ),
      SiteInfoSection(
        title: 'How We Build Trust',
        body:
            'Verified student accounts, reporting, moderation, reviews, order visibility, and clearer support channels.',
      ),
      SiteInfoSection(
        title: 'Startup Direction',
        body:
            'We are shaping Campus Mart into a polished campus commerce product across web and Flutter with safer operations and stronger UX.',
      ),
    ],
  );
}

Widget _buildHelpCenterScreen() {
  return SiteInfoScreen(
    eyebrow: 'Help Center',
    title: 'Quick answers for buying, selling, safety, and support',
    description:
        'Campus Mart ko smooth use karne ke liye common help topics yahan clustered hain. Agar answer na mile, direct support form use kar sakte ho.',
    actions: [
      SiteInfoAction(
        label: 'View FAQ',
        isPrimary: true,
        onTap: () => appNavigatorKey.currentState?.pushNamed('/faq'),
      ),
      SiteInfoAction(
        label: 'Report a Problem',
        onTap: () => appNavigatorKey.currentState?.pushNamed('/report-problem'),
      ),
      SiteInfoAction(
        label: 'Contact Support',
        onTap: () => appNavigatorKey.currentState?.pushNamed('/contact'),
      ),
    ],
    sections: const [
      SiteInfoSection(
        title: 'Account & Login',
        body:
            'Login, registration, OTP verification, account access, and profile basics.',
      ),
      SiteInfoSection(
        title: 'Listings & Selling',
        body:
            'Item add karna, edit karna, sold mark karna, images, and listing quality.',
      ),
      SiteInfoSection(
        title: 'Orders & Payments',
        body:
            'Reservations, payments, disputes, delivery confirmation, and order visibility.',
      ),
      SiteInfoSection(
        title: 'Trust & Safety',
        body:
            'Reports, moderation, suspicious listings, and safer campus deals.',
      ),
    ],
  );
}

Widget _buildFaqScreen() {
  return const SiteInfoScreen(
    eyebrow: 'FAQ',
    title: 'Common questions, clearly answered',
    description:
        'Ye FAQ foundation ka hissa hai aur aage product expand hone ke saath aur mature hoga.',
    sections: [
      SiteInfoSection(
        title: 'How do I sell an item?',
        body:
            'Login karo, List Item par jao, photos and details add karo, then publish.',
      ),
      SiteInfoSection(
        title: 'Is Campus Mart only for students?',
        body:
            'Primary focus student community hai, aur verification layers safer campus commerce ke liye hain.',
      ),
      SiteInfoSection(
        title: 'How do reports work?',
        body:
            'Users listings ko report kar sakte hain, aur admin or moderator review karke action lete hain.',
      ),
      SiteInfoSection(
        title: 'Can I contact the seller directly?',
        body:
            'Haan, item detail se chat aur available contact actions use kar sakte ho.',
      ),
      SiteInfoSection(
        title: 'What if payment or delivery goes wrong?',
        body:
            'Order, dispute flow, and support team escalation dono available hain.',
      ),
    ],
  );
}

Widget _buildCommunityGuidelinesScreen() {
  return const SiteInfoScreen(
    eyebrow: 'Community Guidelines',
    title: 'The rules that keep Campus Mart usable and trustworthy',
    description:
        'A professional marketplace tabhi kaam karta hai jab community behavior predictable, respectful, and honest rahe.',
    sections: [
      SiteInfoSection(
        title: 'Be truthful',
        body:
            'Fake listings, wrong prices, deceptive images, and hidden conditions are not allowed.',
      ),
      SiteInfoSection(
        title: 'Respect users',
        body:
            'Harassment, spam, intimidation, and abusive language are not acceptable.',
      ),
      SiteInfoSection(
        title: 'Trade safely',
        body:
            'Use clear communication, verify item status, and avoid suspicious or rushed payment behavior.',
      ),
      SiteInfoSection(
        title: 'Report problems',
        body:
            'If a listing or user feels unsafe, use report tools or support forms instead of ignoring it.',
      ),
      SiteInfoSection(
        title: 'Follow campus norms',
        body:
            'Use the platform in a way that supports a healthy student community.',
      ),
    ],
  );
}
