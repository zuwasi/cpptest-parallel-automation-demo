# Audit Text Processor: Flow Analysis Requirements

- No variable may be read before it is initialized.
- Every pointer must be validated before dereferencing.
- Every successfully opened file must be closed on every reachable path.

The sample intentionally reads `in_word` before initialization, dereferences `text` before a null check, and contains a reachable file-resource leak.
