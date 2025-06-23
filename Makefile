# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: Canonical Ltd.
.PHONY: check fmt fmt-sh fmt-yaml check-shfmt check-shellcheck check-yaml check-reuse

check: check-shellcheck check-shfmt check-reuse
fmt: fmt-sh fmt-yaml

SCRIPTS_SH=snap-install
# https://github.com/mvdan/sh
check-shfmt:
	shfmt --diff $(SCRIPTS_SH)
fmt-sh:
	shfmt --write $(SCRIPTS_SH)

# https://www.shellcheck.net/
check-shellcheck:
	shellcheck $(SCRIPTS_SH)

# https://github.com/google/yamlfmt
check-yamlfmt:
	yamlfmt -lint -dstar **/*.yaml
fmt-yaml:
	yamlfmt -dstar **/*.yaml

# https://reuse.software/
check-reuse:
	reuse lint
