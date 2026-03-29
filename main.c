#include <stdio.h>

long my_printf(const char* format_string, ...);

int main()
{
    my_printf("Misha %d %x %o %c %s %%\n", 666, 0x200, 16, 'Q', "bad_pig");
    printf("Misha %d %x %o %c %s %%\n", 666, 0x200, 16, 'Q', "bad_pig");
    return 0;
}
