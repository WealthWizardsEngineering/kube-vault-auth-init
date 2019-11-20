build:
	docker-compose -p kube-vault-auth-init -f test/docker-compose.yml build
.PHONY: build

test:
	@ docker-compose -p kube-vault-auth-init -f test/docker-compose.yml run test
	@ docker-compose -p kube-vault-auth-init -f test/docker-compose.yml down
.PHONY: test

tinker:
	docker-compose -p kube-vault-auth-init -f test/docker-compose.yml run test /bin/sh
.PHONY: tinker

clean-up:
	docker-compose -p kube-vault-auth-init -f test/docker-compose.yml down -v
.PHONY: clean-up
