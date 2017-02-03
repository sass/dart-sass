export 'sync_package_resolver/interface.dart'
    if (dart.library.io) 'package:package_resolver/package_resolver.dart'
    if (node) 'sync_package_resolver/node.dart';
