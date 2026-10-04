import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../core/hub_colors.dart';
import '../../core/models.dart';

part 'collapsible_sidebar_state.dart';
part 'collapsible_sidebar_tiles.dart';

class CollapsibleSidebar extends StatefulWidget {
  const CollapsibleSidebar({
    super.key,
    required this.screenWidth,
    required this.appGroups,
    required this.onActionSelected,
    required this.onAppTap,
  });

  final double screenWidth;
  final List<AppGroup> appGroups;
  final ValueChanged<RadialAction> onActionSelected;
  final ValueChanged<HubApp> onAppTap;

  @override
  State<CollapsibleSidebar> createState() => _CollapsibleSidebarState();
}
