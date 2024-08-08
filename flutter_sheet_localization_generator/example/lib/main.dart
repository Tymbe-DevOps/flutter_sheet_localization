import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'localizations.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _currentLocale = Locale('cs');

  @override
  void initState() {
    _currentLocale = localizedLabels.keys.first;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      locale: Locale(_currentLocale.toString()),
      localizationsDelegates: [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: localizedLabels.keys.toList(), // <- Supported locales
      home: MyHomePage(
        title: 'Internationalization demo',
        locale: _currentLocale,
        onLocaleChanged: (locale) {
          if (_currentLocale != locale) {
            setState(() => _currentLocale = locale);
          }
        },
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  MyHomePage({Key? key, required this.title, required this.locale, required this.onLocaleChanged})
      : super(key: key);

  final String title;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    final labels = context.localizations; // <- Accessing your labels
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Column(
        children: <Widget>[
          DropdownButton<Locale>(
            key: Key('Picker'),
            value: locale,
            items: localizedLabels.keys.map((locale) {
              return DropdownMenuItem<Locale>(
                value: locale,
                child: Text(
                  locale.toString(),
                ),
              );
            }).toList(),
            onChanged: (locale) {
              if (locale != null) onLocaleChanged(locale);
            },
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                Text(labels.global.czechCrowns),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
