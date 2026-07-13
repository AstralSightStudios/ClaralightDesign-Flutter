import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:claralight_ui/claralight_ui.dart';

part 'src/gallery_configuration.dart';
part 'src/gallery_app.dart';
part 'src/gallery_home.dart';
part 'src/section_card.dart';
part 'src/sections/control_sections.dart';
part 'src/sections/scrolling_sections.dart';
part 'src/sections/content_sections.dart';
part 'src/sections/interaction_sections.dart';
part 'src/sections/overlay_sections.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CLScrollable.precache();
  runApp(const GalleryApp());
}
