// Threads sharing state. Run with `make test SANITIZE=thread`, ThreadSanitizer
// fails this test if the mutex is removed.
#include <pthread.h>

#define THREADS 4
#define INCREMENTS 10000

static int counter;
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;

static void *
work(void *arg)
{
        (void) arg;
        for (int i = 0; i < INCREMENTS; i++) {
                pthread_mutex_lock(&lock);
                counter++;
                pthread_mutex_unlock(&lock);
        }
        return NULL;
}

int
main(void)
{
        pthread_t threads[THREADS];
        for (int i = 0; i < THREADS; i++)
                if (pthread_create(&threads[i], NULL, work, NULL)) return 1;
        for (int i = 0; i < THREADS; i++)
                pthread_join(threads[i], NULL);
        return counter != THREADS * INCREMENTS;
}
