import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'platform/windows_initializer.dart';
import 'screens/splash_login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

 if (!kIsWeb &&
    defaultTargetPlatform == TargetPlatform.windows) {
  await initializeWindows();
}

  /// CELULAR
if (!kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
     defaultTargetPlatform == TargetPlatform.iOS)) {
    await SystemChrome
        .setPreferredOrientations(
      [
        DeviceOrientation
            .portraitUp,
      ],
    );
  }

  runApp(
    const PlantaoRET(),
  );
}

class PlantaoRET
    extends StatelessWidget {
  const PlantaoRET({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return MaterialApp(
      debugShowCheckedModeBanner:
          false,

      title: 'Plantões RET',

      theme: ThemeData(
        useMaterial3: true,

        brightness:
            Brightness.dark,

        fontFamily: 'Roboto',

        scaffoldBackgroundColor:
            const Color(
          0xFF020B1F,
        ),

        colorScheme:
            ColorScheme.fromSeed(
          seedColor:
              const Color(
            0xFF00AEEF,
          ),
          brightness:
              Brightness.dark,
        ),

        appBarTheme:
            const AppBarTheme(
          backgroundColor:
              Color(
            0xFF02122D,
          ),
          elevation: 0,
          centerTitle: true,
          foregroundColor:
              Colors.white,
        ),

       cardTheme:
    CardThemeData(
  color: const Color(
    0xFF0A1832,
  ),
  elevation: 5,
  shape:
      RoundedRectangleBorder(
    borderRadius:
        BorderRadius.circular(
      18,
    ),
  ),
),
        inputDecorationTheme:
            InputDecorationTheme(
          filled: true,

          fillColor:
              Colors.white
                  .withValues(
            alpha: 0.06,
          ),

          contentPadding:
              const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),

          border:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(
              18,
            ),
            borderSide:
                BorderSide.none,
          ),

          enabledBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(
              18,
            ),
            borderSide:
                const BorderSide(
              color:
                  Colors.white24,
            ),
          ),

          focusedBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(
              18,
            ),
            borderSide:
                const BorderSide(
              color:
                  Color(
                0xFF00C8FF,
              ),
              width: 1.5,
            ),
          ),
        ),

        elevatedButtonTheme:
            ElevatedButtonThemeData(
          style:
              ElevatedButton.styleFrom(
            backgroundColor:
                const Color(
              0xFF0A84FF,
            ),

            foregroundColor:
                Colors.white,

            elevation: 8,

            minimumSize:
                const Size(
              double.infinity,
              58,
            ),

            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(
                18,
              ),
            ),

            textStyle:
                const TextStyle(
              fontSize: 17,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ),

        snackBarTheme:
            SnackBarThemeData(
          behavior:
              SnackBarBehavior
                  .floating,

          backgroundColor:
              Colors.blueGrey
                  .shade900,

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
        ),

        progressIndicatorTheme:
            const ProgressIndicatorThemeData(
          color:
              Color(
            0xFF00C8FF,
          ),
        ),

        checkboxTheme:
            CheckboxThemeData(
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              5,
            ),
          ),
        ),

        chipTheme:
            ChipThemeData(
          backgroundColor:
              Colors.white10,
          selectedColor:
              Colors.blue,
          labelStyle:
              const TextStyle(
            color:
                Colors.white,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              12,
            ),
          ),
        ),
      ),

      home:
          const SplashLoginScreen(),
    );
  }
}