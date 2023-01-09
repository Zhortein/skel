#-----Symfony Projects Makefile-----------------------#
# Author: David RENARD - https://www.david-renard.fr
# License: MIT
#-----------------------------------------------------#

#---VARIABLES AND TOOLS-------------------------------#
ifeq ($(OS),Windows_NT)
	SET = set
else
	SET = export
endif

DOCKER = docker
DOCKER_COMPOSE = docker-compose

COMPOSER = composer

SYMFONY = symfony
SYMFONY_SERVER_START = $(SYMFONY) serve -d
SYMFONY_SERVER_STOP = $(SYMFONY) server:stop
SYMFONY_CONSOLE = $(SYMFONY) console
SYMFONY_LINT = $(SYMFONY_CONSOLE) lint:

NPM = npm

PHPQA = jakzal/phpqa:php8.1
PHPQAMDS = maxdevsolution/phpqa
ifeq ($(OS),Windows_NT)
	PHPQA_RUN = $(DOCKER_RUN) --init -it --rm -v $(CURDIR):/project -w /project $(PHPQA)
	PHPQAMDS_RUN = $(DOCKER_RUN) --init -it --rm -v $(CURDIR):/project -w /project $(PHPQAMDS)
else
	PHPQA_RUN = $(DOCKER_RUN) --init -it --rm -v $(PWD):/project -w /project $(PHPQA)
	PHPQAMDS_RUN = $(DOCKER_RUN) --init -it --rm -v $(PWD):/project -w /project $(PHPQAMDS)
endif

ifeq ($(OS),Windows_NT)
	PHPUNIT = $(SYMFONY) php bin/phpunit
else
	PHPUNIT = APP_ENV=test $(SYMFONY) php bin/phpunit
endif
#-----------------------------------------------------#

## === 🐋  DOCKER ================================================
docker-up: ## Start docker containers.
	$(DOCKER_COMPOSE) build
	$(DOCKER_COMPOSE) up -d
.PHONY: docker-up

docker-stop: ## Stop docker containers.
	$(DOCKER_COMPOSE) stop
.PHONY: docker-stop
#---------------------------------------------#

## === 🔎  TESTS =================================================
tests: ## Run tests.
	$(SET) APP_ENV=test;
	$(SYMFONY) php bin/phpunit --testdox -v
.PHONY: tests

tests-coverage: ## Run tests with coverage.
	$(SET) APP_ENV=test;
	$(SYMFONY) php bin/phpunit --coverage-html var/coverage
.PHONY: tests-coverage
#---------------------------------------------#

first-install: ## Perform first project install
	$(DOCKER_COMPOSE) build
	$(DOCKER_COMPOSE) up -d
	$(COMPOSER) install
	$(NPM) i
	$(NPM) audit fix
	$(NPM) run build
	$(SET) APP_ENV=dev
	$(SYMFONY_CONSOLE) d:d:c --env=dev
	$(SYMFONY_CONSOLE) doctrine:migrations:migrate --no-interaction
	$(SET) APP_ENV=test
	$(SYMFONY_CONSOLE) d:d:c --env=test
	$(SYMFONY_CONSOLE) doctrine:migrations:migrate --no-interaction
	$(SET) APP_ENV=dev
	$(SYMFONY_SERVER_START)
.PHONY: first-install

before-commit:
	$(PHPQA_RUN) local-php-security-checker  --path=./composer.lock
	$(PHPQA_RUN) php-cs-fixer fix ./src --rules=@Symfony --verbose
	$(DOCKER) build -t maxdevsolution/phpqa -f docker/Dockerfile.phpstan .
	$(PHPQAMDS_RUN) phpstan analyse ./src --level=7 -c docker/phpstan.neon
	$(PHPQA_RUN) twig-lint lint ./templates
	$(SYMFONY_LINT)yaml ./config
	$(SYMFONY_LINT)container
	$(SYMFONY_CONSOLE) doctrine:schema:validate --skip-sync -vvv --no-interaction
	$(SET) APP_ENV=test;
	$(SYMFONY) php bin/phpunit --testdox -v
	$(SET) APP_ENV=dev
.PHONY: before-commit

qa-metrics:
	$(SET) APP_ENV=test;
	$(SYMFONY) php bin/phpunit --coverage-html var/coverage
	$(PHPQA_RUN) phpmetrics --report-html=var/phpmetrics ./src
	$(SET) APP_ENV=dev
.PHONY: qa-metrics