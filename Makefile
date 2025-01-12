.PHONY: test eastwood cljfmt install smoketest deploy clean detect_timeout

CLOJURE_VERSION ?= 1.10

test/resources/cider/nrepl/clojuredocs/export.edn:
	curl -o $@ https://github.com/clojure-emacs/clojuredocs-export-edn/raw/master/exports/export.compact.edn

.inline-deps: clean
	lein with-profile -user,-dev inline-deps
	touch .inline-deps

inline-deps: .inline-deps

test: clean .inline-deps test/resources/cider/nrepl/clojuredocs/export.edn
	lein with-profile -user,-dev,+$(CLOJURE_VERSION),+test,+plugin.mranderson/config test

quick-test: clean
	lein with-profile -user,-dev,+$(CLOJURE_VERSION),+test test

tools-deps-test: clean install
	cd tools-deps-testing; clojure -M:test

eastwood:
	lein with-profile -user,-dev,+$(CLOJURE_VERSION),+deploy,+eastwood eastwood

cljfmt:
	lein with-profile -user,-dev,+$(CLOJURE_VERSION),+cljfmt cljfmt check

kondo:
	lein with-profile -user,-dev,+clj-kondo run -m clj-kondo.main --lint src .circleci/deploy

install: check-install-env .inline-deps
	lein with-profile -user,-dev,+$(CLOJURE_VERSION),+plugin.mranderson/config install

smoketest: install
	cd test/smoketest && \
        lein with-profile -user,-dev,+$(CLOJURE_VERSION) uberjar && \
        java -jar target/smoketest-0.1.0-SNAPSHOT-standalone.jar


# Run a background process that prints all JVM stacktraces after five minutes,
# then kills all JVMs, to help diagnose issues with ClojureScript tests getting
# stuck.
detect_timeout:
	(bin/ci_detect_timeout &)

# Deployment is performed via CI by creating a git tag prefixed with "v".
# Please do not deploy locally as it skips various measures (particularly around mranderson).
deploy: check-env .inline-deps
	lein with-profile -user,+$(CLOJURE_VERSION),+plugin.mranderson/config deploy clojars

check-env:
ifndef CLOJARS_USERNAME
	$(error CLOJARS_USERNAME is undefined)
endif
ifndef CLOJARS_PASSWORD
	$(error CLOJARS_PASSWORD is undefined)
endif
ifndef CIRCLE_TAG
	$(error CIRCLE_TAG is undefined. Please only perform deployments by publishing git tags. CI will do the rest.)
endif

check-install-env:
ifndef PROJECT_VERSION
	$(error Please set PROJECT_VERSION as an env var beforehand.)
endif

clean:
	lein clean
	cd test/smoketest && lein clean
	rm -f .inline-deps
