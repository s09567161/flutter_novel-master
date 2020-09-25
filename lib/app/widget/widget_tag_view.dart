import 'package:flutter/material.dart';

/// refer:https://github.com/shichunlei/flutter_app/blob/555d4e6b9714695629e4286f4d3b9d585fd4713d/lib/ui/tagview.dart
class TagView extends StatelessWidget {
  final String tag;
  final Color textColor;
  final Color borderColor;
  final EdgeInsetsGeometry padding;
  final Color bgColor;
  final VoidCallback onPressed;
  final double borderRadius;
  final double fontSize;

  TagView(
      {Key key,
      @required this.tag,
      this.textColor,
      this.borderColor,
      this.padding,
      this.bgColor,
      this.onPressed,
      this.borderRadius: 3.0,
      this.fontSize = 11.5})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          padding: padding ?? EdgeInsets.symmetric(horizontal: 5),
          child: Text(
            tag,
            style: TextStyle(
              color: textColor ?? Color(0xFF9A9AA7),
              fontSize: fontSize,
            ),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
            border:
                Border.all(width: 0.5, color: borderColor ?? Color(0xFF9A9AA7)),
            color: bgColor ?? Colors.transparent,
          ),
        ),
      ),
    );
  }
}
