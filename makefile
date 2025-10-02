rc:
	odin build . -out:rc
	./rc input

clean:
	rm -f ./rc

.PHONY: rc clean
