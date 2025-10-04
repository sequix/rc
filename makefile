rc:
	odin build . -out:rc

test:
	odin test . -define:ODIN_TEST_THREADS=1 -define:ODIN_TEST_TRACK_MEMORY=false

test-leak:
	odin test . -define:ODIN_TEST_THREADS=1

clean:
	rm -f ./rc

.PHONY: rc test clean test-leak
