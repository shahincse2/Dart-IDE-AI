import 'package:flutter/material.dart';

import '../../utils/constants.dart';

/// One row of the file tree: an icon (or, while selecting several, a tick
/// box), the name, and for a folder an arrow.
class EntryRow extends StatelessWidget {
  final IconData icon;
  final IconData? trailingIcon;

  /// Tapping the arrow alone. Null: the arrow is only a picture and the whole
  /// row does the tapping.
  final VoidCallback? onTrailingTap;
  final String label;
  final int depth;

  /// Highlighted like the open file is.
  final bool selected;

  /// Null outside selection mode; otherwise whether this row is ticked.
  final bool? checked;
  final bool openIndicator;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const EntryRow({
    super.key,
    required this.icon,
    this.trailingIcon,
    this.onTrailingTap,
    required this.label,
    required this.depth,
    this.selected = false,
    this.checked,
    this.openIndicator = false,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ticked = checked ?? false;
    final highlighted = selected || ticked;
    final trailing = trailingIcon;

    return Material(
      color: highlighted
          ? scheme.primaryContainer.withValues(alpha: 0.4)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: EdgeInsets.only(
            left: AppConstants.spaceMd + depth * AppConstants.spaceLg,
            right: AppConstants.spaceMd,
            top: AppConstants.spaceSm,
            bottom: AppConstants.spaceSm,
          ),
          child: Row(
            children: [
              Icon(
                checked == null
                    ? icon
                    : (ticked ? Icons.check_box : Icons.check_box_outline_blank),
                size: 18,
                color: ticked ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppConstants.spaceSm),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: highlighted ? FontWeight.w600 : FontWeight.normal,
                    color: highlighted ? scheme.primary : scheme.onSurface,
                  ),
                ),
              ),
              if (openIndicator)
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant, shape: BoxShape.circle),
                ),
              if (trailing != null)
                InkResponse(
                  onTap: onTrailingTap,
                  radius: 18,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(trailing, size: 16, color: scheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
