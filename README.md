# horlang
Stack-based 2-dimensional toy programming language

Demo on asciinema: https://asciinema.org/a/zaZU1o3Z5joZHjvA6SQUl4Gsc


## Introduction
* The instruction pointer consists of two special registers R (row) and C (column). After each non-jump instruction execution moves one column to the right. The program terminates when instruction pointer moves outside of the file.
* Values of R and C registers can be modified which causes the execution to move to the specific location.
* There are two general use registers A and B that may be used.
* For storing more values there is a stack (max size = 65535).
* Execution state is always either TRUE or FALSE. Instructions can behave differently based on this value. At the beginning of the program the execution state is always TRUE.
* Every instruction in Horlang is a single character.
* The only datatype is a 16-bit unsigned integer.
* Arithmetic operations such as `+` and `*` wrap around on overflow.


| cmd           |                                                                                                                                                                                                   |
|---------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| A,B           | Pop top value from stack and assigns it to register                                                                                                                                               |
| a,b,r,c       | Push value of register on top of stack                                                                                                                                                            |
| R,C           | Pop top value from stack and assigns it to register, immediately moving instruction pointer to the specified location                                                                             |
| ?             | Pop top value from the stack. If the value was 0, execution state is changed to TRUE, otherwise FALSE                                                                                             |
| z             | Clear the stack (registers are unaffected)                                                                                                                                                        |
| U             | Step execution up one step (decrements R).                                                                                                                                                        |
| u             | Step execution up one step IF execution state is TRUE. Otherwise does nothing.                                                                                                                    |
| D             | Step execution down one step (increments R).                                                                                                                                                      |
| d             | Step execution down one step IF execution state is TRUE. Otherwise does nothing.                                                                                                                  |
| x             | Exit immediately IF execution state is TRUE. Otherwise does nothing.                                                                                                                              |
| p             | Interpret entire stack as ASCII (topmost value being the last character) and prints it to current output stream (default=STDOUT).                                                                 |
| P             | Print a representation of the stack to current output stream (default=STDOUT).                                                                                                                    |
| #             | Print the topmost value in the stack as a number to current output stream.                                                                                                                        |
| .             | Interpret the topmost value as ASCII and prints it to current output stream.                                                                                                                      |
| ,             | Print a space character to current output stream.                                                                                                                                                 |
| ;             | Print a newline character to current output stream.                                                                                                                                               |
| +, -, *, /, % | Pop two topmost values from stack and pushes the result of an arithmetic operation on top of the stack. The topmost value will be on the left side of the operation.                              |
| =, <, >       | Pop two topmost values from the stack and pushes the result of comparison operation (0 for FALSE, 1 for TRUE) on top of the stack. The topmost value will be on the left side of the operation.   |
| Numbers 0-9   | Push corresponding numeric value on top of the stack.                                                                                                                                             |
| g             | Read a byte from current input stream (default=STDIN) and push it onto the stack.                                                                                                                 |
| F             | Interpret entire stack as ASCII filename (topmost value being the last character) and open the file for reading.                                                                                  |
| f             | Close opened file and set current input stream back to STDIN. If no file was opened, does nothing.                                                                                                |
| "             | Toggle LITERAL interpretation mode. In literal mode all bytes are treated as their ASCII values.                                                                                                  |
| '             | Toggle NUMERIC interpretation mode. When exiting numeric mode the full "string" of characters is interpreted as a number. Examples of valid numeric literals are `'123'`, `'0xFF'`, `'0b101'`, `'9_001'.` |


## Installing

You will need [Crystal-lang](https://crystal-lang.org/) compiler (tested on 1.7.2, other versions will probably work but no guarantees).

```
$ crystal build -o horlang --release cli.cr
$ ./horlang --help
```
