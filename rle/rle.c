#include <stdio.h>
#include <stdlib.h>

void emit(int c, int count);

int main(void)
{
	int c, lastc, count;

	lastc = -1;
	count = 0;

	while((c = getchar()) != -1) {
		if(c == lastc && count < 127) {
			count++;
		} else {
			emit(lastc, count);
			count = 1;
			lastc = c;
		}
	}
	emit(lastc, count);

	return 0;
}

void emit(int c, int count)
{
	if(count <= 0 || c < 0) return;

	fprintf(stderr, "emit(%d, %d) -> ", c, count);
	if(count > 2 || (c & 0x80)) {
		fprintf(stderr, "%02x %02x\n", (unsigned int)count | 0x80, (unsigned int)c);
		putchar(count | 0x80);
		putchar(c);
	} else {
		while(count--) {
			fprintf(stderr, "%02x\n", (unsigned int)c & 0x7f);
			putchar(c);
		}
	}
}
