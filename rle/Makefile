all: rle unrle

rle: rle.o
	$(CC) -o $@ $< $(LDFLAGS)

unrle: unrle.o
	$(CC) -o $@ $< $(LDFLAGS)

clean:
	$(RM) rle.o
	$(RM) rle
	$(RM) unrle.o
	$(RM) unrle
