#include "ring_buffer.h"

#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv)
{
    ring_buffer_t buffer;
    char command[16];
    int value;

    if (argc > 1) {
        strcpy(command, argv[1]);
        printf("command=%s\n", command);
    }

    ring_buffer_init(&buffer);
    (void)ring_buffer_push(&buffer, INT_MAX);
    (void)ring_buffer_push(&buffer, 20);

    while (ring_buffer_pop(&buffer, &value)) {
        printf("%d\n", value + 1);
    }

    return 0;
}
