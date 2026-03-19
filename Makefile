.PHONY: bootstrap bootstrap-with-commands bootstrap-full test-bootstrap

bootstrap:
	@test -n "$(TARGET)" || (echo "TARGET is required" && exit 1)
	@bash scripts/bootstrap-project.sh --target "$(TARGET)" $(if $(SEED_MODULE),--seed-module "$(SEED_MODULE)",) --platform "$(or $(PLATFORM),claude)"

bootstrap-with-commands:
	@test -n "$(TARGET)" || (echo "TARGET is required" && exit 1)
	@bash scripts/bootstrap-project.sh --target "$(TARGET)" $(if $(SEED_MODULE),--seed-module "$(SEED_MODULE)",) --platform "$(or $(PLATFORM),claude)" --copy-commands

bootstrap-full:
	@test -n "$(TARGET)" || (echo "TARGET is required" && exit 1)
	@bash scripts/bootstrap-project.sh --target "$(TARGET)" $(if $(SEED_MODULE),--seed-module "$(SEED_MODULE)",) --platform "$(or $(PLATFORM),claude)" --copy-commands --copy-skills

test-bootstrap:
	@bash tests/bootstrap-project.test.sh
