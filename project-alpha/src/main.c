#include "statistics.h"

#include <stdio.h>

int main(void)
{
    const int samples[] = {4, 8, 15, 16, 23, 42};
    const size_t count = sizeof(samples) / sizeof(samples[0]);

    printf("mean=%.2f maximum=%d\n", mean(samples, count), maximum(samples, count));
    return 0;
}
