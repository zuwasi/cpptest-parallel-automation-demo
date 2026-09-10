# Flight Sensor Statistics: MISRA C Requirements

- **MISRA-15.6:** Every iteration statement and `if` statement body shall be a compound statement.
- **MISRA-10.4:** Both operands of an operator in the usual arithmetic conversions shall have the same essential type category.
- **MISRA-12.2:** Shift and arithmetic operations shall remain within the underlying type range.

The sample intentionally omits braces and mixes signed and unsigned operands so the dashboard has known MISRA C violations to demonstrate.
