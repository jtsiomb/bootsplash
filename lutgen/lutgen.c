#include <stdio.h>
#include <math.h>

int main(void)
{
	int i;

	printf("sintab:\n");
	for(i=0; i<256; i++) {
		float x = sin((float)i / 128.0f * M_PI);
		printf("\tdb %d\n", (int)(x * 127.5f - 0.5f));
	}
	return 0;
}
