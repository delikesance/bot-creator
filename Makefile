REMOTE ?= origin
PROTECTED_BRANCHES ?= main master develop dev

.PHONY: clean-merged-branches dry-run-clean-merged-branches

clean-merged-branches:
	@set -e; \
	git fetch --prune $(REMOTE); \
	default_branch=$$(git symbolic-ref --quiet --short refs/remotes/$(REMOTE)/HEAD 2>/dev/null | sed 's#^$(REMOTE)/##'); \
	if [ -z "$$default_branch" ]; then \
		echo "Cannot detect $(REMOTE) default branch (refs/remotes/$(REMOTE)/HEAD)."; \
		exit 1; \
	fi; \
	current_branch=$$(git rev-parse --abbrev-ref HEAD); \
	protected="$(PROTECTED_BRANCHES) $$default_branch $$current_branch"; \
	echo "Remote: $(REMOTE)"; \
	echo "Default branch: $$default_branch"; \
	echo "Protected branches: $$protected"; \
	git branch --format='%(refname:short)' --merged "$(REMOTE)/$$default_branch" | while read -r branch; do \
		[ -z "$$branch" ] && continue; \
		if echo "$$protected" | tr ' ' '\n' | grep -Fxq "$$branch"; then \
			continue; \
		fi; \
		echo "Deleting local merged branch: $$branch"; \
		git branch -d "$$branch"; \
	done

dry-run-clean-merged-branches:
	@set -e; \
	git fetch --prune $(REMOTE); \
	default_branch=$$(git symbolic-ref --quiet --short refs/remotes/$(REMOTE)/HEAD 2>/dev/null | sed 's#^$(REMOTE)/##'); \
	if [ -z "$$default_branch" ]; then \
		echo "Cannot detect $(REMOTE) default branch (refs/remotes/$(REMOTE)/HEAD)."; \
		exit 1; \
	fi; \
	current_branch=$$(git rev-parse --abbrev-ref HEAD); \
	protected="$(PROTECTED_BRANCHES) $$default_branch $$current_branch"; \
	echo "Remote: $(REMOTE)"; \
	echo "Default branch: $$default_branch"; \
	echo "Protected branches: $$protected"; \
	echo "Branches that would be deleted:"; \
	git branch --format='%(refname:short)' --merged "$(REMOTE)/$$default_branch" | while read -r branch; do \
		[ -z "$$branch" ] && continue; \
		if echo "$$protected" | tr ' ' '\n' | grep -Fxq "$$branch"; then \
			continue; \
		fi; \
		echo " - $$branch"; \
	done
