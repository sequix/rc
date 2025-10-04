rc:
	odin build . -out:rc

test:
	odin test . \
		-max-error-count:1 \
		-define:ODIN_TEST_THREADS=1 \
		-define:ODIN_TEST_TRACK_MEMORY=false \
		-define:ODIN_TEST_FANCY=false \
		-define:ODIN_TEST_LOG_LEVEL=error

clean:
	rm -f ./rc

.PHONY: rc test clean test-leak
