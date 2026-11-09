test:
	lua5.1 scripts/busted.lua

package: test
	python3 -I scripts/package.py

.PHONY: test package
