.PHONY: all
all : cf2f funclist

.PHONY: clean
clean :
	$(RM) cf2f ./obj/cf2f.yy.c
	$(RM) funclist ./obj/funclist.yy.c

./obj/cf2f.yy.c : ./src/cf2f.l
	@if [ ! -d obj ]; then \
		mkdir obj; \
	fi
	$(LEX) -o./obj/cf2f.yy.c ./src/cf2f.l

./obj/funclist.yy.c : ./src/funclist.l
	@if [ ! -d obj ]; then \
		mkdir obj; \
	fi
	$(LEX) -o./obj/funclist.yy.c ./src/funclist.l

cf2f : ./obj/cf2f.yy.c ./src/main.c ./src/SBuf.c -lfl
	$(CC) -pedantic -o cf2f ./obj/cf2f.yy.c ./src/main.c ./src/SBuf.c -L/usr/lib -lfl -I./src

funclist : ./obj/funclist.yy.c ./src/main.c ./src/SBuf.c -lfl
	$(CC) -pedantic -o funclist ./obj/funclist.yy.c ./src/main.c ./src/SBuf.c -L/usr/lib -lfl -I./src
