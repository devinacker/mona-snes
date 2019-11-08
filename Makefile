
mona.sfc: mona.s DATA.BIN linker.cfg
	ca65 -g -o mona.o mona.s
	ld65 -C linker.cfg -o mona.sfc -Ln mona.sym mona.o
	