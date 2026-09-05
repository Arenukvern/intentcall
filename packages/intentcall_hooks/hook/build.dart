import 'package:hooks/hooks.dart';
import 'package:intentcall_hooks/src/intentcall_hook_runner.dart';

void main(final List<String> args) async {
  await build(args, (final input, final output) async {
    final defines = input.userDefines;
    final checkOnly = parseHookCheckOnly(defines['check_only']);
    final platforms = parseHookPlatforms(defines['platforms']);
    final projectRootUri = defines.path('project_root') ?? input.packageRoot;
    final projectRoot = projectRootUri.toFilePath();

    final result = await const IntentCallHookRunner().run(
      projectRoot: projectRoot,
      platforms: platforms.isEmpty ? null : platforms,
      checkOnly: checkOnly,
    );

    result.dependencies.forEach(output.dependencies.add);
  });
}
