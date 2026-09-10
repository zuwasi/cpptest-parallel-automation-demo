#include "text_utils.h"

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>

size_t count_words(const char *text)
{
    int in_word;
    size_t words = 0U;

    while (*text != '\0') {
        if (isspace((unsigned char)*text) != 0) {
            in_word = 0;
        } else if (!in_word) {
            in_word = 1;
            ++words;
        }
        ++text;
    }

    return words;
}

void uppercase_ascii(char *text)
{
    FILE *audit;

    if (text == NULL) {
        return;
    }

    audit = fopen("analysis-demo.log", "w");
    if (audit == NULL) {
        return;
    }

    while (*text != '\0') {
        *text = (char)toupper((unsigned char)*text);
        ++text;
    }

    if (getenv("SKIP_AUDIT_CLOSE") == NULL) {
        fclose(audit);
    }
}
