# Copyright (c) 2022 SAP SE or an SAP affiliate company. All rights reserved. This file is licensed under the Apache Software License, v. 2 except as noted otherwise in the LICENSE file
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


REGISTRY          := $(shell cat .REGISTRY 2>/dev/null)
PUSH_LATEST_TAG   := true
VERSION           := $(shell cat VERSION)
EFFECTIVE_VERSION := $(VERSION)-$(shell git rev-parse --short HEAD)
OS                := linux
ARCH              := amd64

IMG_CLA_ASSISTANT := cla-assistant
REG_CLA_ASSISTANT := $(REGISTRY)/$(IMG_CLA_ASSISTANT)


#########################################
# Tools                                 #
#########################################

TOOLS_DIR := hack/tools
include hack/tools.mk


#################################################################
# Rules related to binary build, Docker image build and release #
#################################################################
.PHONY: docker-images
docker-images:
ifeq ("$(REGISTRY)", "")
	@echo "Please set your docker registry in REGISTRY variable or .REGISTRY file first."; false;
endif
	@echo "Building docker images with version and tag $(EFFECTIVE_VERSION)"
	@docker build --build-arg EFFECTIVE_VERSION=$(EFFECTIVE_VERSION) --build-arg ARCH=$(ARCH) --build-arg OS=$(OS) -t $(REG_CLA_ASSISTANT):$(EFFECTIVE_VERSION) -t $(REG_CLA_ASSISTANT):latest -f Dockerfile --target $(IMG_CLA_ASSISTANT) .

.PHONY: docker-push
docker-push:
ifeq ("$(REGISTRY)", "")
	@echo "Please set your docker registry in REGISTRY variable or .REGISTRY file first."; false;
endif
	@if ! docker images $(REG_CLA_ASSISTANT) | awk '{ print $$2 }' | grep -q -F $(EFFECTIVE_VERSION); then echo "$(REG_CLA_ASSISTANT) version $(EFFECTIVE_VERSION) is not yet built. Please run 'make docker-images'"; false; fi
	@docker push $(REG_CLA_ASSISTANT):$(EFFECTIVE_VERSION)
ifeq ("$(PUSH_LATEST_TAG)", "true")
	@docker push $(REG_CLA_ASSISTANT):latest
endif


#####################################################################
# Rules for verification, formatting, linting, testing and cleaning #
#####################################################################

.PHONY: check
check: $(GOIMPORTS) $(GOLANGCI_LINT)
	@hack/check.sh --golangci-lint-config=./.golangci.yaml ./prow/...

.PHONY: revendor
revendor:
	@GO111MODULE=on go mod tidy
	@GO111MODULE=on go mod vendor

.PHONY: verify-modules
verify-vendor: revendor
	@if !(git diff --quiet HEAD -- go.sum go.mod vendor); then \
		echo "go module files or vendor folder are out of date, please run 'make revendor'"; exit 1; \
	fi

.PHONY: test
test:
	@./hack/test.sh ./prow/...

.PHONY: test-cov
test-cov:
	@./hack/test-cover.sh ./prow/...