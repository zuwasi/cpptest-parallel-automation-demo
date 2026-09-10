#include "ring_buffer.h"

void ring_buffer_init(ring_buffer_t *buffer)
{
    if (buffer != NULL) {
        buffer->read_index = 0U;
        buffer->write_index = 0U;
        buffer->size = 0U;
    }
}

bool ring_buffer_push(ring_buffer_t *buffer, int value)
{
    if ((buffer == NULL) || (buffer->size == RING_BUFFER_CAPACITY)) {
        return false;
    }

    buffer->values[buffer->write_index] = value;
    buffer->write_index = (buffer->write_index + 1U) % RING_BUFFER_CAPACITY;
    ++buffer->size;
    return true;
}

bool ring_buffer_pop(ring_buffer_t *buffer, int *value)
{
    if ((buffer == NULL) || (value == NULL) || (buffer->size == 0U)) {
        return false;
    }

    *value = buffer->values[buffer->read_index];
    buffer->read_index = (buffer->read_index + 1U) % RING_BUFFER_CAPACITY;
    --buffer->size;
    return true;
}
