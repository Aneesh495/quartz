# Quartz builds with LDC or DMD. No third-party D libraries are required.
# Compiler detection happens in the recipe so a toolchain installed by
# tools/ensure_ldc.sh is visible before Dub is invoked.

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
export PATH := $(ROOT)/.toolchain/bin:$(PATH)

DUB ?= dub

.PHONY: all release test check demo clean toolchain

all: toolchain
	@compiler='$(COMPILER)'; \
	if [ -z "$$compiler" ]; then compiler=$$(bash $(ROOT)/tools/compiler.sh); fi; \
	$(DUB) build --compiler="$$compiler" --build=debug

release: toolchain
	@compiler='$(COMPILER)'; \
	if [ -z "$$compiler" ]; then compiler=$$(bash $(ROOT)/tools/compiler.sh); fi; \
	$(DUB) build --compiler="$$compiler" --build=release

test: toolchain
	@compiler='$(COMPILER)'; \
	if [ -z "$$compiler" ]; then compiler=$$(bash $(ROOT)/tools/compiler.sh); fi; \
	$(DUB) test --compiler="$$compiler"

check: all test
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
	@bash $(ROOT)/tools/ensure_ldc.sh

clean:
	-$(DUB) clean
	rm -rf .dub .runtime quartz quartz-test
