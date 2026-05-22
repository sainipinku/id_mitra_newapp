
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:idmitra/Widgets/AppSize.dart';
import 'package:idmitra/bloc_provider/bloc_provider.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/screens/dashboard/users/user_details_page.dart';
import 'package:idmitra/screens/splash/splash.dart';
import 'package:idmitra/utils/GlobalContext.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/services/maintenance_service.dart';
import 'package:idmitra/services/no_internet_service.dart';

void main() async{

  WidgetsFlutterBinding.ensureInitialized();

  MaintenanceService.instance.init(Config.proBaseUrl);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );


  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NoInternetService.instance.init();
      MaintenanceService.instance.checkOnStartup();
    });
  }

  @override
  Widget build(BuildContext context) {
    AppSize.init(context);
    return MultiBlocProvider(
      providers: BlocProviders.providers,

      child: ScreenUtilInit(
        designSize: const Size(375, 812),  // FIXED DESIGN SIZE
        builder: (context, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            navigatorKey: GlobalContext.navigatorKey,

            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(1.0)),
                child: child!,
              );

            },
            theme: ThemeData(
              useMaterial3: false,
              scaffoldBackgroundColor: AppTheme.appBackgroundColor, // ✅ Global background
              dividerTheme: const DividerThemeData(
                thickness: 1,
                space: 1,
              ),
              appBarTheme: const AppBarTheme(
                systemOverlayStyle: SystemUiOverlayStyle(
                  statusBarColor: Colors.white,              // ✅ yahan change
                  statusBarIconBrightness: Brightness.dark,  // ✅ Android black icons
                  statusBarBrightness: Brightness.light,     // ✅ iOS black text
                ),
                backgroundColor: AppTheme.appBackgroundColor,
                elevation: 0,
              ),

            ),
            home: Splash(),
          );
        },
      ),
    );
  }
}


