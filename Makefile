#=============================================
#                User Settings
#=============================================
# Use this to pick a particular python executable
PYTHON ?= python3
NODE_VERSION ?= 22.9.0

#=============================================
#   Ignore self signed certificate errors
#=============================================
# See: https://stackoverflow.com/questions/52478069/node-fetch-disable-ssl-verification
export NODE_TLS_REJECT_UNAUTHORIZED ?= 0

#=============================================
#             Python specific Settings
#=============================================
PYTHON_VERSION := $(shell $(PYTHON) --version | awk '{print $$NF;}')
PYTHON_MAJOR_VERSION := $(word 1,$(subst ., ,$(PYTHON_VERSION)))

#=============================================
#                Default Target
#=============================================
all: install

install: venv/bin/pnpm
	. venv/bin/activate && pnpm install

run: install
	. venv/bin/activate && pnpm dev

venv/bin/pnpm: venv/bin/npm
	. venv/bin/activate && npm install --global --prefix venv --prefer-offline --no-audit pnpm

#=============================================
#            CDK/NPM Environment
#=============================================
cdk: | venv/bin/cdk

venv/bin/cdk: venv/bin/npm venv/bin/aws
	. venv/bin/activate && \
	cd venv && \
	npm config set strict-ssl false && \
	npm install --global --prefix . --prefer-offline --no-audit aws-cdk && \
	cd lib/node_modules/aws-cdk && \
	npm link

venv/bin/npm: | venv/bin/node

# See: https://stackoverflow.com/questions/39566769/install-npm-packages-in-python-virtualenv
# May need SSL_CERT_FILE to be set
venv/bin/node: | venv
	@venv/bin/nodeenv \
		--node $(NODE_VERSION) \
		--ignore_ssl_certs \
		--python-virtualenv

venv/bin/aws: $(DOWNLOAD_FOLDER)/awscli
	@$</aws/install \
		--update \
		--bin-dir $(shell readlink -f venv)/bin \
		--install-dir $(shell readlink -f venv)/aws-cli

$(DOWNLOAD_FOLDER)/awscli: $(DOWNLOAD_FOLDER)/awscliv2.zip
	@unzip -q -u -d $@ $<

$(DOWNLOAD_FOLDER)/awscliv2.zip: $(DOWNLOAD_FOLDER)
	@wget --quiet -O $@ $(AWSCLI_DOWNLOAD_URL)

#=============================================
#                Environment
#=============================================
environment: venv

venv: venv/bin

venv/bin:
	@echo "Creating new Python virtual environment ..." >&2

ifeq ($(PYTHON_MAJOR_VERSION),3)
	@$(PYTHON) -m venv $(dir $@) --system-site-packages
else
	@$(dir $(shell which $(PYTHON)))/virtualenv $(dir $@) --system-site-packages --no-setuptools
endif

	@$@/pip install --upgrade pip pip-tools nodeenv $(PIP_INSTALL_OPTIONS)

#=============================================
#                Cleanup
#=============================================
clean:
	-@rm -rf venv || true
	-@rm -rf .eggs tmp pkg_* build *.egg-info .pytest_cache .coverage || true
	-@find . -type f \( -name '*.py[co]' -o -name __pycache_ \) -exec rm {} \; || true
