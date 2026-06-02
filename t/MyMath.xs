#include <math.h>

MODULE = MyMath    PACKAGE = MyMath

int
add(a, b)
    int a
    int b
    CODE:
        RETVAL = a + b;
    OUTPUT:
        RETVAL

double
multiply(x, y)
    double x
    double y
    CODE:
        RETVAL = x * y;
    OUTPUT:
        RETVAL

int
factorial(n)
    int n
    CODE:
        RETVAL = 1;
        for (int i = 2; i <= n; i++) { RETVAL *= i; }
    OUTPUT:
        RETVAL

double
sqrt_val(x)
    double x
    CODE:
        RETVAL = sqrt(x);
    OUTPUT:
        RETVAL
