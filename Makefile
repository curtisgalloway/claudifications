SCHEME  = Claudifications
CONFIG  = Release
OUTDIR  = build/Release

# Extra xcodebuild settings; release CI passes MARKETING_VERSION and
# CURRENT_PROJECT_VERSION here to stamp the build from the git tag.
XCFLAGS ?=

.PHONY: generate build install clean

generate:
	xcodegen generate

build: generate
	xcodebuild -scheme $(SCHEME) -configuration $(CONFIG) \
		CONFIGURATION_BUILD_DIR=$(PWD)/$(OUTDIR) \
		$(XCFLAGS) \
		build

install: build
	rm -rf /Applications/Claudifications.app
	cp -R $(OUTDIR)/Claudifications.app /Applications/

clean:
	rm -rf build
