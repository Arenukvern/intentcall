.PHONY: test analyze publish-dry-run
INTENTCALL_PKGS := packages/intentcall_schema packages/intentcall_core packages/intentcall_mcp \
	packages/intentcall_webmcp packages/intentcall_gemma packages/intentcall_apple \
	packages/intentcall_android packages/intentcall_platform packages/intentcall_codegen \
	packages/intentcall_testing

test:
	dart test $(INTENTCALL_PKGS)

analyze:
	dart analyze .

publish-dry-run:
	bash tool/intentcall/publish_all.sh
