.PHONY: all
all : cf2f

.PHONY: clean
clean :
	$(RM) cf2f ./obj/cf2f.yy.c

./obj/cf2f.yy.c : ./src/cf2f.l
	@if [ ! -d obj ]; then \
		mkdir obj; \
	fi
	$(LEX) -o./obj/cf2f.yy.c ./src/cf2f.l

cf2f : ./obj/cf2f.yy.c ./src/main.c ./src/SBuf.c -lfl
	$(CC) -pedantic -o cf2f ./obj/cf2f.yy.c ./src/main.c ./src/SBuf.c -L/usr/lib -lfl -I./src
