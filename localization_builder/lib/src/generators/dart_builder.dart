import 'package:dart_style/dart_style.dart';
import 'package:localization_builder/src/definitions/category.dart';
import 'package:localization_builder/src/definitions/condition.dart';
import 'package:localization_builder/src/definitions/localizations.dart';
import 'package:localization_builder/src/definitions/section.dart';
import 'package:localization_builder/src/generators/builders/base.dart';
import 'package:localization_builder/src/generators/builders/property.dart';

import 'builders/argument.dart';
import 'builders/data_class.dart';

class DartLocalizationBuilder {
  DartLocalizationBuilder({
    this.nullSafety = true,
    this.jsonParser = true,
    this.fallbackLocale,
  });

  StringBuffer _buffer = StringBuffer();
  final bool nullSafety;
  final bool jsonParser;
  final String? fallbackLocale;

  String buildImports() {
    return '''
import 'dart:ui';
import 'package:template_string/template_string.dart';
    ''';
  }

  String build(Localizations localizations) {
    _buffer = StringBuffer();

    _createLocalization(
      [
        localizations.name,
      ],
      localizations,
    );
    localizations.categories.forEach((c) => _addCategoryDefinition(c));
    _addSectionDefinition(
      [
        localizations.name,
      ],
      localizations,
    );
    return DartFormatter(languageVersion: DartFormatter.latestLanguageVersion)
        .format(_buffer.toString());
  }

  void _createLocalization(List<String> path, Localizations localizations) {
    _buffer.writeln('final localizedLabels = ${_createLanguageMap(path, localizations)};');
  }

  String _createLanguageMap(List<String> path, Localizations localizations) {
    final result = StringBuffer();

    result.write(' <Locale, ${_buildClassNameFromPath(path)}>{');

    for (var languageCode in localizations.supportedLanguageCodes) {
      final instance = _createSectionInstance(path, languageCode, localizations);

      final splits = languageCode.split(RegExp(r'[-_]'));

      var key = 'Locale.fromSubtags(languageCode: \'${splits.first}\'';
      if (splits.length > 2) {
        key += ', scriptCode: \'${splits[1]}\'';
        key += ', countryCode: \'${splits[2]}\'';
      } else if (splits.length > 1) {
        key += ', countryCode: \'${splits[1]}\'';
      }
      key += ')';
      result.write(key + ' : ' + instance + ',');
    }

    result.write('}');

    return result.toString();
  }

  String _createSectionInstance(
    List<String> path,
    String languageCode,
    Section section,
  ) {
    path = [
      ...path,
      section.normalizedKey,
    ];

    final result = StringBuffer();
    result.writeln('const ${_buildClassNameFromPath(path)}(');

    for (var localizationLabel in section.labels) {
      for (var labelVariant in localizationLabel.cases) {
        String fieldName;
        if (labelVariant.condition is CategoryCondition) {
          final categoryCondition = labelVariant.condition as CategoryCondition;
          fieldName =
              '${localizationLabel.normalizedKey}${createClassName(categoryCondition.value)}';
        } else {
          fieldName = '${localizationLabel.normalizedKey}';
        }
        result.write(fieldName);

        var matchingTranslation = labelVariant.translations
            .firstWhere((translation) => translation.languageCode == languageCode);

        var finalTranslationValue = matchingTranslation.value;

        if (fallbackLocale != null && matchingTranslation.value.isEmpty) {
          matchingTranslation = labelVariant.translations
              .firstWhere((translation) => translation.languageCode == fallbackLocale);
          finalTranslationValue = matchingTranslation.value;
        } else if (fallbackLocale == null && matchingTranslation.value.isEmpty) {
          final pathWithoutPrefix = [...path];
          pathWithoutPrefix.removeRange(0, 2);

          finalTranslationValue =
              pathWithoutPrefix.join('.') + '.${localizationLabel.normalizedKey}';
        }
        result.write(':');
        result.write('\'${_escapeString(finalTranslationValue)}\',');
      }
    }

    for (var child in section.children) {
      result.write(child.normalizedKey);
      result.write(':');
      result.write(_createSectionInstance(
        path,
        languageCode,
        child,
      ));
      result.write(',');
    }

    result.writeln(')');

    return result.toString();
  }

  void _addCategoryDefinition(Category category) {
    final values = category.values.map((x) => x + ',').join();
    _buffer.writeln('enum ${category.normalizedName} { $values }');
  }

  void _addSectionDefinition(List<String> path, Section section) {
    path = [
      ...path,
      section.normalizedKey,
    ];

    final result = DataClassBuilder(
      _buildClassNameFromPath(path),
      isConst: true,
    );

    for (var label in section.labels) {
      if (label.templatedValues.isEmpty &&
          label.cases.length == 1 &&
          label.cases.first.condition is DefaultCondition) {
        result.addProperty('String', label.normalizedKey);
      } else {
        final methodArguments = <ArgumentBuilder>[];

        /// Adding an argument for each category
        final categoryCases = label.cases.where((x) => x.condition is CategoryCondition);
        for (var categoryCase in categoryCases) {
          final condition = categoryCase.condition as CategoryCondition;
          final fieldName = '_${label.normalizedKey}${createClassName(condition.value)}';
          result.addProperty('String', fieldName);
        }

        /// Adding an argument for each category
        final categories = categoryCases
            .map((e) => e.condition)
            .cast<CategoryCondition>()
            .map((x) => x.name)
            .toSet();
        for (var categoryName in categories) {
          final categoryClassName = createClassName(categoryName);
          methodArguments.add(
            ArgumentBuilder(
              name: createFieldName(categoryName),
              type: categoryClassName,
            ),
          );
        }

        /// Default value
        final defaultCase = label.cases.map((x) => x.condition).whereType<DefaultCondition>();

        if (defaultCase.isNotEmpty) {
          result.addProperty('String', '_${label.normalizedKey}');
        }

        /// Adding an argument for each templated value
        for (var templatedValue in label.templatedValues) {
          methodArguments.add(
            ArgumentBuilder(
              name: createFieldName(templatedValue.key),
              type: templatedValue.type,
            ),
          );
        }
        if (label.templatedValues.isNotEmpty) {
          methodArguments.add(
            ArgumentBuilder(
              name: 'locale',
              type: 'String?',
              isRequired: false,
            ),
          );
        }

        /// Creating method body
        final body = StringBuffer('{\n');

        for (var c in label.cases.where((x) => x.condition is CategoryCondition)) {
          final condition = c.condition as CategoryCondition;
          final categoryField = createFieldName(condition.name);
          final categoryClassName = createClassName(condition.name);
          final categoryValue = '$categoryClassName.${createFieldName(condition.value)}';
          body.writeln('if($categoryField == $categoryValue) { ');

          body.write('return _${label.normalizedKey}${createClassName(condition.value)}');
          if (label.templatedValues.isNotEmpty) {
            body.write('.insertTemplateValues({');
            for (var templatedValue in label.templatedValues) {
              body.write('\'${templatedValue.key}\' : ${createFieldName(templatedValue.key)},');
            }
            body.write('}, locale : locale,)');
          }
          body.writeln(';');

          body.writeln('}');
        }

        if (defaultCase.isNotEmpty) {
          body.write('return _${label.normalizedKey}');
          if (label.templatedValues.isNotEmpty) {
            body.write('.insertTemplateValues({');
            for (var templatedValue in label.templatedValues) {
              body.write('\'${templatedValue.key}\' : ${createFieldName(templatedValue.key)},');
            }
            body.write('}, locale: locale,)');
          }
          body.writeln(';');
        } else {
          body.write('throw Exception();');
        }

        body.writeln('}');

        result.addMethod(
          returnType: 'String',
          name: label.normalizedKey,
          body: body.toString(),
          arguments: methodArguments,
        );
      }
    }

    for (var child in section.children) {
      final childPath = [
        ...path,
        child.normalizedKey,
      ];
      result.addProperty(
        _buildClassNameFromPath(childPath),
        createFieldName(child.key),
        jsonConverter: fromJsonPropertyBuilderJsonConverter,
      );
    }

    _buffer.writeln(
      result.build(
        nullSafety: nullSafety,
        jsonParser: jsonParser,
      ),
    );

    for (var child in section.children) {
      _addSectionDefinition(path, child);
    }
  }
}

String _buildClassNameFromPath(List<String> path) {
  return path.map((name) => createClassName(name)).join();
}

String _escapeString(String value) =>
    value.replaceAll('\n', '\\n').replaceAll('\'', '\\\'').replaceAll('\$', '\\\$');
