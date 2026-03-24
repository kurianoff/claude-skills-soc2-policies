build:
	mkdir -p dist
	cd skills && zip -r ../dist/soc2-policies.skill soc2-policies/
	cd skills && zip -r ../dist/policy-review.skill policy-review/
	cd skills && zip -r ../dist/policy-export.skill policy-export/

clean:
	rm -f dist/*.skill

.PHONY: build clean
