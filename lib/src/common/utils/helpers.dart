import 'dart:math';

import 'package:cloud_text_to_speech/cloud_text_to_speech.dart';
import 'package:xml/xml.dart';

class Helpers {
  Helpers._();

  static String formatLanguageCountry(String? language, String? country) {
    if (language == null && country == null) {
      return '';
    } else if (country == null) {
      return language ?? '';
    } else if (language == null) {
      return '';
    } else {
      return '$language($country)';
    }
  }

  static String sanitizeSsml(
      String ssml, Map<String, List<String>> allowedElements) {
    if (!ssml.trim().startsWith("<speak")) {
      ssml = "<speak>" + ssml + "</speak>";
    }

    var document = XmlDocument.parse(ssml);
    var rootElement = document.rootElement;

    _sanitizeNode(rootElement, allowedElements);

    if (!allowedElements.containsKey('speak')) {
      return rootElement.children
          .map((child) => child.toXmlString(pretty: true))
          .join();
    } else {
      return document.toXmlString(pretty: true);
    }
  }

  static void _sanitizeNode(
      XmlNode node, Map<String, List<String>> allowedElements) {
    if (node.nodeType == XmlNodeType.ELEMENT) {
      var element = node as XmlElement;

      // Go through all the children first
      for (var child in List.from(element.children)) {
        _sanitizeNode(child, allowedElements);
      }

      // If the element itself is not allowed, replace it with its children
      if (!allowedElements.containsKey(element.name.local)) {
        var parent = element.parent;
        if (parent != null) {
          int index = parent.children.indexOf(element);
          parent.children.removeAt(index);
          List<XmlNode> childrenCopy =
              element.children.map((node) => node.copy()).toList();
          parent.children.insertAll(index, childrenCopy);
        }
      } else {
        // Otherwise, check the attributes
        var allowedAttributes = allowedElements[element.name.local] ?? [];
        for (var attribute in element.attributes.toList()) {
          if (!allowedAttributes.contains(attribute.name.local)) {
            element.attributes.remove(attribute);
          }
        }
      }
    } else if (node.nodeType == XmlNodeType.TEXT) {
      var text = node as XmlText;
      if (text.value.trim().isEmpty) {
        text.remove();
      }
    }
  }

  static List<String> shuffleNamesByText(
    List<String> names,
    String text,
  ) {
    List<int> indices = List<int>.generate(names.length, (index) => index);

    List<int> seed = text.codeUnits.toList();
    Random random =
        Random(seed.fold<int>(0, (prev, element) => prev + element));

    for (int i = names.length - 1; i > 0; i--) {
      int j = random.nextInt(i + 1);
      int temp = indices[i];
      indices[i] = indices[j];
      indices[j] = temp;
    }

    List<String> shuffledNames = List<String>.from(names);

    for (int i = 0; i < names.length; i++) {
      shuffledNames[indices[i]] = names[i];
    }

    return shuffledNames;
  }

  static List<T> mapVoiceNames<T extends VoiceUniversal>(List<T> voices,
      List<String> maleVoiceNames, List<String> femaleVoiceNames) {
    String locale = '';
    String gender = '';
    List<String> names = [];
    int nameIndex = 0;

    return voices.map((e) {
      if (locale != e.locale || gender != e.gender) {
        nameIndex = 0;
        locale = e.locale;
        gender = e.gender;
        switch (gender.toLowerCase()) {
          case 'male':
            names = shuffleNamesByText(maleVoiceNames, locale);
            break;
          case 'female':
          case 'neutral':
          default:
            names = shuffleNamesByText(femaleVoiceNames, locale);
        }
      }

      if (names.isNotEmpty) {
        if (nameIndex >= names.length) {
          nameIndex = 0;
        }

        e.name = names[nameIndex];
        e.nativeName = names[nameIndex];
      }

      nameIndex++;
      return e;
    }).toList(growable: false);
  }
}
