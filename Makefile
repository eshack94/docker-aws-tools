OS_KERNEL := $(shell uname -s)
ifeq ($(OS_KERNEL), Darwin)
	HOST_IP := $(shell ifconfig en0 | awk '$$1 == "inet" { print $$2 }')
	MAKE_DISPLAY := $(HOST_IP):0
else
	MAKE_DISPLAY := $(DISPLAY)
endif

.PHONY: build clean cli gui help osx-display requirements test ~/.aws ~/.gitconfig ~/.ssh

help:
	@echo 'The following make commands are available'
	@echo '    make cli   - shows a CLI.'
	@echo '    make gui   - shows a VS Code editor (requires X11 or XQuartz on Mac).'
	@echo '    make test  - runs infra tests against the aws-tools docker image.'
	@echo '    make clean - Removes docker image created.'

clean:
	docker rmi aws-tools
	@echo 'Also run "docker image prune" for additional cleanup.'

requirements:
	@/bin/bash -lc 'type docker' > /dev/null || (echo 'ERROR: Docker needs to be installed.  If on Mac OS X, install Docker for Mac.' >&2; false)

~/.aws:
	[ -d ~/.aws ] || mkdir -p ~/.aws

~/.gitconfig:
	[ -f ~/.gitconfig ] || touch ~/.gitconfig

~/.ssh:
	[ -d ~/.ssh ] || ( mkdir -p ~/.ssh; chmod 700 ~/.ssh )

cli: build ~/.aws ~/.gitconfig ~/.ssh
	docker run -it --rm \
		-v ~/.ssh:/home/aws-user/.ssh \
		-v ~/.gitconfig:/home/aws-user/.gitconfig \
		-v ~/.aws:/home/aws-user/.aws \
		-v $(PWD):/mnt \
		-w /mnt aws-tools

gui: build osx-display ~/.aws ~/.gitconfig ~/.ssh
	docker run --rm -tie DISPLAY=$(MAKE_DISPLAY) \
		-v ~/.ssh:/home/aws-user/.ssh \
		-v ~/.gitconfig:/home/aws-user/.gitconfig \
		-v ~/.aws:/home/aws-user/.aws \
		-v /tmp/.X11-unix:/tmp/.X11-unix \
		-v $(PWD):/mnt \
		-w /mnt aws-tools code -w /mnt

build: requirements
	docker build . -t aws-tools

test: build
	docker run --rm -iu root aws-tools /usr/local/bin/goss -g - validate < goss.yaml

osx-display:
	set -ex; if [ "$(OS_KERNEL)" = 'Darwin' ]; then \
		type -p XQuartz > /dev/null || (echo 'ERROR: XQuartz must be installed.' >&2; false); \
		open -a XQuartz; \
		defaults write org.macosforge.xquartz.X11 nolisten_tcp -boolean false; \
		xhost +$(HOST_IP); \
	fi
