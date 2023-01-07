# Quartz builds with LDC or DMD. No third-party D libraries are required.

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
export PATH := $(ROOT)/.toolchain/bin:$(PATH)

DUB ?= dub
COMPILER ?=

ifeq ($(COMPILER),)
  COMPILER := $(shell command -v ldc2 >/dev/null 2>&1 && echo ldc2 || (command -v dmd >/dev/null 2>&1 && echo dmd || echo))
endif

.PHONY: all test check demo clean toolchain

all: toolchain
	$(DUB) build --compiler=$(COMPILER) --build=debug

release: toolchain
	$(DUB) build --compiler=$(COMPILER) --build=release

test: toolchain
	$(DUB) test --compiler=$(COMPILER)

check: test
	./quartz loopback
	./quartz theory bpsk --ebn0 0,4,8
	./quartz run examples/bpsk_awgn.qz --out .runtime/bpsk
	./quartz run examples/qpsk_rrc.qz --out .runtime/qpsk
	./quartz run examples/ofdm_wifi.qz --out .runtime/wifi
	./quartz explain examples/ofdm_wifi.qz

demo: all
	./quartz loopback
	./quartz theory bpsk --ebn0 0,2,4,6,8
	./quartz ber examples/bpsk_awgn.qz --from 0 --to 8 --step 2 --bits 12000 --out .runtime/ber
	./quartz run examples/ofdm_wifi.qz --out .runtime/wifi

toolchain:
	@if [ -z "$(COMPILER)" ]; then \
		echo "No D compiler on PATH. Running tools/ensure_ldc.sh"; \
		bash $(ROOT)/tools/ensure_ldc.sh; \
		if ! command -v ldc2 >/dev/null 2>&1; then \
			echo "ldc2 is still unavailable. Install LDC and retry." >&2; \
			exit 1; \
		fi; \
	fi

clean:
	-$(DUB) clean
	rm -rf .dub .runtime quartz quartz-test
