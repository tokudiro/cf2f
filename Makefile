.PHONY: all
all : cf2f funclist cf2v

.PHONY: clean
clean :
	$(RM) cf2f ./obj/cf2f.yy.c
	$(RM) funclist
	$(RM) cf2v ./obj/cf2v.yy.c

./obj/cf2f.yy.c : ./src/cf2f.l
	@if [ ! -d obj ]; then \
		mkdir obj; \
	fi
	$(LEX) -o./obj/cf2f.yy.c ./src/cf2f.l

./obj/cf2v.yy.c : ./src/cf2v.l
	@if [ ! -d obj ]; then \
		mkdir obj; \
	fi
	$(LEX) -o./obj/cf2v.yy.c ./src/cf2v.l

cf2f : ./obj/cf2f.yy.c ./src/main.c ./src/SBuf.c -lfl
	$(CC) -pedantic -o cf2f ./obj/cf2f.yy.c ./src/main.c ./src/SBuf.c -L/usr/lib -lfl -I./src

funclist : ./obj/cf2f.yy.c ./src/main.c ./src/SBuf.c -lfl
	$(CC) -pedantic -o funclist ./obj/cf2f.yy.c ./src/main.c ./src/SBuf.c -L/usr/lib -lfl -I./src -DFUNCLIST

cf2v : ./obj/cf2v.yy.c ./src/main.c ./src/SBuf.c -lfl
	$(CC) -pedantic -o cf2v ./obj/cf2v.yy.c ./src/main.c ./src/SBuf.c -L/usr/lib -lfl -I./src -DUSE_TYPE_BUFFER

.PHONY: test
test : cf2f funclist cf2v
	./tests/run.sh cf2f
	./tests/run.sh funclist
	./tests/run.sh cf2v
