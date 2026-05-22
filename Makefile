SCHEME  = Claudifications
CONFIG  = Release
OUTDIR  = build/Release

.PHONY: generate build install clean

generate:
	xcodegen generate

build: generate
	xcodebuild -scheme $(SCHEME) -configuration $(CONFIG) \
		CONFIGURATION_BUILD_DIR=$(PWD)/$(OUTDIR) \
		build

install: build
	rm -rf /Applications/Claudifications.app
	cp -R $(OUTDIR)/Claudifications.app /Applications/

clean:
	rm -rf build
