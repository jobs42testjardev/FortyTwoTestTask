ifneq (,$(wildcard ./.env))
	include .env
	export
endif

DOCKER_CMD_PREFIX=./docker/compose.sh
ifeq (,$(USE_LOCAL))
	MANAGE=$(DOCKER_CMD_PREFIX) run --rm backend python manage.py
else
	MANAGE=python manage.py
endif
TEST_SETTINGS=fortytwo.test_settings
TEST_APP=apps/

# Dev servers
run:
	@echo Starting http://127.0.0.1:8000
ifeq (,$(USE_LOCAL))
	$(DOCKER_CMD_PREFIX) up
else
	(trap 'kill 0' SIGINT; $(MANAGE) runserver & yarn --cwd frontend serve)
endif

# Database
migrate:
	$(MANAGE) migrate --noinput

migrations:
	$(MANAGE) makemigrations

createcachetable:
	@echo Creating cache table
	$(MANAGE) createcachetable

initproject: migrate createcachetable

# Testing
shell:
	@echo Starting shell...
	$(MANAGE) shell

cmd=black apps && flake8 apps
lint:
ifeq (,$(USE_LOCAL))
	$(DOCKER_CMD_PREFIX) run backend sh -c "$(cmd)"
else
	$(cmd)
endif

djangotest:
	$(MANAGE) test --settings=$(TEST_SETTINGS) $(TEST_APP) --noinput

coverage:
	coverage run manage.py test --settings=$(TEST_SETTINGS) $(TEST_APP) && coverage report -i

test: lint djangotest

collectstatic:
	@echo Collecting static files
	$(MANAGE) collectstatic --noinput

eslint:
ifeq (,$(USE_LOCAL))
	$(DOCKER_CMD_PREFIX) run frontend sh -c "yarn --cwd /app/frontend lint src --fix"
else
	yarn --cwd frontend lint src --fix
endif

# Deploy
DEPLOY_CONT_ID=fortytwotesttask
build:
ifeq (,$(USE_LOCAL))
	docker build --tag=$(DEPLOY_CONT_ID):latest .
else
	yarn --cwd frontend install
	yarn --cwd frontend build
	$(MAKE) collectstatic
endif

server:
ifeq (,$(USE_LOCAL))
	docker run -p=8000:8000 --rm --name $(DEPLOY_CONT_ID) $(DEPLOY_CONT_ID):latest
else
	./docker/backend-cmd.sh
endif

h-deploy:
ifeq (,$(HEROKU_APP_NAME))
	@echo Missing HEROKU_APP_NAME env var
else
	@echo Deploying on heroku
	heroku container:push web --app $(HEROKU_APP_NAME)
	heroku container:release web --app $(HEROKU_APP_NAME)
endif
