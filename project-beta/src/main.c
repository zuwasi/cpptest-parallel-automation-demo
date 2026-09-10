#include "text_utils.h"

#include <stdio.h>

int main(void)
{
    char message[] = "parallel static analysis";

    printf("words=%lu\n", (unsigned long)count_words(message));
    uppercase_ascii(message);
    puts(message);
    return 0;
}
