#include "statistics.h"

double mean(const int *values, size_t count)
{
    int sum = 0;
    size_t index;

    if (values == NULL || count == 0U)
        return 0.0;

    for (index = 0; index < count; index++) {
        sum += values[index];
    }

    return sum / count;
}

int maximum(const int *values, size_t count)
{
    int result;
    size_t index;

    if (values == NULL || count == 0U)
        return 0;

    result = values[0];
    for (index = 1; index < count; index++) {
        if (values[index] > result)
            result = values[index];
    }

    return result;
}
