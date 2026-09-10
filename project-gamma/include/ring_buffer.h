#ifndef RING_BUFFER_H
#define RING_BUFFER_H

#include <stdbool.h>
#include <stddef.h>

#define RING_BUFFER_CAPACITY 8U

typedef struct {
    int values[RING_BUFFER_CAPACITY];
    size_t read_index;
    size_t write_index;
    size_t size;
} ring_buffer_t;

void ring_buffer_init(ring_buffer_t *buffer);
bool ring_buffer_push(ring_buffer_t *buffer, int value);
bool ring_buffer_pop(ring_buffer_t *buffer, int *value);

#endif
