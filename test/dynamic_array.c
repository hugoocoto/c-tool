// Tests are self-contained programs: exit 0 if everything is fine
#include <assert.h>
#include <stdlib.h>
#include <string.h>

#include "cum.h"

int
main(void)
{
        Da(int) da = { 0 };
        for (int i = 0; i < 100; i++)
                Da_append(&da, i);
        assert(da.count == 100);

        Da_remove(&da, 0);
        assert(da.count == 99 && da.items[0] == 1);

        int sum = 0;
        Da_foreach(x, da) sum += *x;
        assert(sum == 99 * 100 / 2);

        Da_destroy(&da);
        return 0;
}
