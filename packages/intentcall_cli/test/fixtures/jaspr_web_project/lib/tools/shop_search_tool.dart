import 'package:intentcall_codegen/intentcall_codegen.dart';
import 'package:intentcall_core/intentcall_core.dart';
import 'package:intentcall_schema/intentcall_schema.dart';

part 'shop_search_tool.g.dart';

@AgentTool(namespace: 'shop', name: 'search', description: 'Search catalog')
Future<AgentResult> shopSearch(@AgentParam('Query') final String query) async =>
    AgentResult.success(data: {'query': query});
