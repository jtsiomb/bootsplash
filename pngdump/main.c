#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include "image.h"

void print_usage(const char *argv0);

int main(int argc, char **argv)
{
	int i, mode = 0;
	int text = 0;
	char *fname = 0, *outfname = 0;
	struct image img;
	FILE *out = stdout;

	for(i=1; i<argc; i++) {
		if(argv[i][0] == '-') {
			if(argv[i][2] == 0) {
				switch(argv[i][1]) {
				case 'p':
					mode = 0;
					break;

				case 'c':
					mode = 1;
					break;

				case 'i':
					mode = 2;
					break;

				case 't':
					text = 1;
					break;

				case 'o':
					if(!argv[++i]) {
						fprintf(stderr, "%s must be followed by a filename\n", argv[i - 1]);
						return 1;
					}
					outfname = argv[i];
					break;

				case 'h':
					print_usage(argv[0]);
					return 0;

				default:
					fprintf(stderr, "invalid option: %s\n", argv[i]);
					print_usage(argv[0]);
					return 1;
				}
			} else {
				fprintf(stderr, "invalid option: %s\n", argv[i]);
				print_usage(argv[0]);
				return 1;
			}
		} else {
			if(fname) {
				fprintf(stderr, "unexpected argument: %s\n", argv[i]);
				print_usage(argv[0]);
				return 1;
			}
			fname = argv[i];
		}
	}

	if(!fname) {
		fprintf(stderr, "pass the filename of a PNG file\n");
		return 1;
	}
	if(load_image(&img, fname) == -1) {
		fprintf(stderr, "failed to load PNG file: %s\n", fname);
		return 1;
	}

	if(outfname) {
		if(!(out = fopen(outfname, "wb"))) {
			fprintf(stderr, "failed to open output file: %s: %s\n", outfname, strerror(errno));
			return 1;
		}
	}

	switch(mode) {
	case 0:
		fwrite(img.pixels, 1, img.scansz * img.height, out);
		break;

	case 1:
		if(text) {
			for(i=0; i<img.cmap_ncolors; i++) {
				printf("%d %d %d\n", img.cmap[i].r, img.cmap[i].g, img.cmap[i].b);
			}
		} else {
			fwrite(img.cmap, sizeof img.cmap[0], img.cmap_ncolors, out);
		}
		break;

	case 2:
		printf("size: %dx%d\n", img.width, img.height);
		printf("bit depth: %d\n", img.bpp);
		printf("scanline size: %d bytes\n", img.scansz);
		if(img.cmap_ncolors > 0) {
			printf("colormap entries: %d\n", img.cmap_ncolors);
		} else {
			printf("color channels: %d\n", img.nchan);
		}
		break;
	}

	fclose(out);
	return 0;
}

void print_usage(const char *argv0)
{
	printf("Usage: %s [options] <input file>\n", argv0);
	printf("Options:\n");
	printf(" -p: dump pixels (default)\n");
	printf(" -c: dump colormap (palette) entries\n");
	printf(" -i: print image information\n");
	printf(" -t: dump as text\n");
	printf(" -h: print usage and exit\n");
}
