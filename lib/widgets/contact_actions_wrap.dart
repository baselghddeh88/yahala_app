import 'package:flutter/material.dart';

class ContactActionData {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const ContactActionData({
    required this.color,
    required this.icon,
    required this.label,
    required this.onPressed,
  });
}

class ContactActionsWrap extends StatelessWidget {
  final List<ContactActionData> actions;
  final Widget? trailing;
  final double spacing;
  final double runSpacing;
  final double buttonHeight;

  const ContactActionsWrap({
    super.key,
    required this.actions,
    this.trailing,
    this.spacing = 8,
    this.runSpacing = 8,
    this.buttonHeight = 48,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final columns = maxWidth >= 520
            ? actions.length.clamp(1, 3)
            : maxWidth >= 340
            ? 2
            : 1;
        final buttonWidth = columns <= 1
            ? maxWidth
            : (maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          alignment: WrapAlignment.spaceBetween,
          children: [
            ...actions.map(
              (action) => SizedBox(
                width: buttonWidth,
                child: _ContactActionButton(
                  action: action,
                  height: buttonHeight,
                ),
              ),
            ),
            if (trailing != null)
              SizedBox(
                width: 54,
                height: buttonHeight,
                child: Center(child: trailing),
              ),
          ],
        );
      },
    );
  }
}

class _ContactActionButton extends StatelessWidget {
  final ContactActionData action;
  final double height;

  const _ContactActionButton({required this.action, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: action.color,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: action.onPressed,
        icon: Icon(action.icon, color: Colors.white, size: 20),
        label: Text(
          action.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
