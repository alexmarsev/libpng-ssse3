/* ssse3_init.c - SSSE3 optimised filter functions
 *
 * Copyright (c) 2012-2013 Alex Marsev
 *
 * This code is released under the libpng license.
 * For conditions of distribution and use, see the disclaimer
 * and license in png.h
 */
#ifdef PNG_ALIGNED_MEMORY_SUPPORTED
#include "../pngpriv.h"

void png_init_filter_functions_ssse3(png_structp pp, unsigned int bpp) {
	if (png_check_cpu_for_ssse3()) {
		pp->read_filter[PNG_FILTER_VALUE_UP-1] = png_read_filter_row_up_sse2;
		if (bpp == 4) {
			pp->read_filter[PNG_FILTER_VALUE_SUB-1] = png_read_filter_row_sub4_ssse3;
			pp->read_filter[PNG_FILTER_VALUE_AVG-1] = png_read_filter_row_avg4_ssse3;
			pp->read_filter[PNG_FILTER_VALUE_PAETH-1] = png_read_filter_row_paeth4_ssse3;
		} else if (bpp == 3) {
			pp->read_filter[PNG_FILTER_VALUE_SUB-1] = png_read_filter_row_sub3_ssse3;
			pp->read_filter[PNG_FILTER_VALUE_AVG-1] = png_read_filter_row_avg3_ssse3;
			pp->read_filter[PNG_FILTER_VALUE_PAETH-1] = png_read_filter_row_paeth3_ssse3;
		}
	}
}

#endif
