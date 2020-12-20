LDFLAGS = -lpng -lz

pngdump: main.o image.o
	$(CC) -o $@ $^ $(LDFLAGS)

clean:
	$(RM) main.o
	$(RM) image.o
	$(RM) pngdump
