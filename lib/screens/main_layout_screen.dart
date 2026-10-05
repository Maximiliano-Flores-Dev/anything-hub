import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/hub_colors.dart';
import '../core/logger.dart';
import '../core/models.dart';
import '../modules/projects/services/project_activation_service.dart';
import '../modules/projects/services/project_fs_service.dart';
import '../modules/projects/ui/advisement_modal.dart';
import '../modules/projects/ui/projects_screen.dart';
import '../services/device_apps_service.dart';
import '../ui/sidebar/collapsible_sidebar.dart';
import '../ui/widgets/card_arts.dart';
import '../ui/widgets/dashboard_card.dart';
import '../ui/widgets/gradient_pill_button.dart';
import '../modules/apps/ui/mis_aplicaciones_screen.dart';
import '../modules/apps/ui/apk_incoming_sheet.dart';
import 'file_explorer_screen.dart';
import 'web_links_screen.dart';
