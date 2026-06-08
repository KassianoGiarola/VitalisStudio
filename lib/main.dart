import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/app_colors.dart';
import 'firebase_options.dart';
import 'pages/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ColorScheme _buildColorScheme() {
    return ColorScheme.fromSeed(
      seedColor: VitalisColors.azulMarinhoProfundo,
      brightness: Brightness.light,
    ).copyWith(
      primary: VitalisColors.azulMarinhoProfundo,
      secondary: VitalisColors.verdeEsmeralda,
      tertiary: VitalisColors.cobreQueimado,
      surface: VitalisColors.surface,
      error: VitalisColors.erro,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: VitalisColors.pretoSuave,
    );
  }

  TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: VitalisColors.azulMarinhoProfundo,
        letterSpacing: -0.4,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: VitalisColors.azulMarinhoProfundo,
        letterSpacing: -0.3,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: VitalisColors.azulMarinhoProfundo,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: VitalisColors.azulMarinhoProfundo,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: VitalisColors.azulMarinhoProfundo,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: VitalisColors.azulMarinhoProfundo,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.45,
        color: VitalisColors.cinzaEscuro,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.4,
        color: VitalisColors.cinzaEscuro,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12.5,
        height: 1.35,
        color: VitalisColors.cinzaMedio,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: VitalisColors.azulMarinhoProfundo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = _buildColorScheme();

    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: VitalisColors.offWhite,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vitalis Studio',
      theme: baseTheme.copyWith(
        textTheme: _buildTextTheme(baseTheme.textTheme),

        appBarTheme: const AppBarTheme(
          backgroundColor: VitalisColors.azulMarinhoProfundo,
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.1,
          ),
          iconTheme: IconThemeData(color: Colors.white, size: 24),
          actionsIconTheme: IconThemeData(color: Colors.white, size: 23),
        ),

        drawerTheme: const DrawerThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),

        cardTheme: CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.black.withOpacity(0.06),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: VitalisColors.borda, width: 1),
          ),
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
        ),

        listTileTheme: ListTileThemeData(
          iconColor: VitalisColors.azulMarinhoProfundo,
          textColor: VitalisColors.pretoSuave,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 6,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          titleTextStyle: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            color: VitalisColors.pretoSuave,
          ),
          subtitleTextStyle: const TextStyle(
            fontSize: 13.5,
            color: VitalisColors.cinzaMedio,
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: VitalisColors.verdeEsmeralda,
            foregroundColor: Colors.white,
            disabledBackgroundColor: VitalisColors.cinzaClaro,
            disabledForegroundColor: VitalisColors.cinzaMedio,
            elevation: 0,
            shadowColor: Colors.transparent,
            minimumSize: const Size(double.infinity, 52),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            side: const BorderSide(color: VitalisColors.borda, width: 1.2),
            foregroundColor: VitalisColors.azulMarinhoProfundo,
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: VitalisColors.azulMarinhoProfundo,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),

        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: VitalisColors.verdeEsmeralda,
          foregroundColor: Colors.white,
          elevation: 4,
          focusElevation: 4,
          hoverElevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
          extendedTextStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),

        iconTheme: const IconThemeData(
          color: VitalisColors.azulMarinhoProfundo,
          size: 24,
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          hintStyle: const TextStyle(
            color: VitalisColors.cinzaMedio,
            fontSize: 14,
          ),
          labelStyle: const TextStyle(
            color: VitalisColors.azulMarinhoProfundo,
            fontWeight: FontWeight.w600,
          ),
          floatingLabelStyle: const TextStyle(
            color: VitalisColors.verdeEsmeralda,
            fontWeight: FontWeight.w700,
          ),
          prefixIconColor: VitalisColors.cinzaMedio,
          suffixIconColor: VitalisColors.cinzaMedio,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: VitalisColors.borda, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: VitalisColors.borda, width: 1),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(
              color: VitalisColors.verdeEsmeralda,
              width: 1.8,
            ),
          ),
          errorBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: VitalisColors.erro, width: 1.4),
          ),
          focusedErrorBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: VitalisColors.erro, width: 1.8),
          ),
        ),

        dropdownMenuTheme: DropdownMenuThemeData(
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),

        dialogTheme: DialogThemeData(
          backgroundColor: VitalisColors.offWhite,
          surfaceTintColor: Colors.transparent,
          elevation: 12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: VitalisColors.azulMarinhoProfundo,
          ),
          contentTextStyle: const TextStyle(
            fontSize: 14.5,
            height: 1.45,
            color: VitalisColors.cinzaEscuro,
          ),
        ),

        chipTheme: ChipThemeData(
          backgroundColor: VitalisColors.verdeSuave,
          selectedColor: VitalisColors.verdeEsmeralda.withOpacity(0.16),
          disabledColor: VitalisColors.cinzaClaro,
          side: const BorderSide(color: VitalisColors.borda),
          labelStyle: const TextStyle(
            color: VitalisColors.azulMarinhoProfundo,
            fontWeight: FontWeight.w700,
          ),
          secondaryLabelStyle: const TextStyle(
            color: VitalisColors.azulMarinhoProfundo,
            fontWeight: FontWeight.w700,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),

        switchTheme: SwitchThemeData(
          thumbColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return VitalisColors.verdeEsmeralda;
            }
            return VitalisColors.cinzaMedio;
          }),
          trackColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return VitalisColors.verdeEsmeralda.withOpacity(0.28);
            }
            return VitalisColors.cinzaClaro;
          }),
        ),

        checkboxTheme: CheckboxThemeData(
          fillColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return VitalisColors.verdeEsmeralda;
            }
            return Colors.transparent;
          }),
          checkColor: MaterialStateProperty.all(Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          side: const BorderSide(color: VitalisColors.cinzaMedio, width: 1.4),
        ),

        radioTheme: RadioThemeData(
          fillColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return VitalisColors.verdeEsmeralda;
            }
            return VitalisColors.cinzaMedio;
          }),
        ),

        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: VitalisColors.verdeEsmeralda,
          linearTrackColor: VitalisColors.cinzaClaro,
          circularTrackColor: VitalisColors.cinzaClaro,
        ),

        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: VitalisColors.azulMarinhoProfundo,
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),

        dividerTheme: const DividerThemeData(
          color: VitalisColors.borda,
          thickness: 1,
          space: 20,
        ),

        tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
            color: VitalisColors.azulMarinhoProfundo,
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}
