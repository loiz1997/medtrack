import 'package:flutter/material.dart';

/// Unique test IDs for UI automation (Katalon Studio / Appium).
///
/// Flutter's `Key` is invisible to Appium. `Semantics(identifier: ...)` is
/// published to the phone's accessibility tree instead:
///   * Android -> `resource-id`
///   * iOS     -> accessibility identifier (`name`)
///
/// Use the helper that matches the widget:
///   * [button] - buttons (same pattern the login screen already used)
///   * [field]  - text inputs, dropdowns and text
///   * [group]  - cards, rows, lists, tabs, switches and badges
class TestId {
  TestId._();

  /// One clean accessibility node for a button, carrying [id].
  static Widget button(String id, Widget child, {String? label}) => Semantics(
        identifier: id,
        label: label ?? id,
        button: true,
        explicitChildNodes: false,
        child: ExcludeSemantics(child: child),
      );

  /// Merges [id] into a text input, dropdown or text widget.
  static Widget field(String id, Widget child) =>
      Semantics(identifier: id, child: child);

  /// A container node with [id] that keeps its children accessible.
  static Widget group(String id, Widget child) =>
      Semantics(identifier: id, container: true, child: child);
}
