#include <stdio.h>

int main(void)
{
	int c, count, rawbytes = 0;

	printf("P5\n320 200\n255\n");

	while((c = getchar()) != -1) {
		if(c & 0x80) {
			count = c & 0x7f;
			if((c = getchar()) == -1) {
				fprintf(stderr, "Unexpected EOF while decoding RLE data\n");
				return 1;
			}
			rawbytes += count;
			while(count--) putchar(c);
		} else {
			rawbytes++;
			putchar(c);
		}
	}

	fprintf(stderr, "decoded (raw) size: %d bytes\n", rawbytes);
	return 0;
}
