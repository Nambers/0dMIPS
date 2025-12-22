#ifndef OPTNONE_H
#define OPTNONE_H

#if defined(__GNUC__)
#define NONOPT __attribute__((noinline, optimize("O0")))
#elif defined(__clang__)
#define NONOPT __attribute__((optnone))
#endif

#endif // OPTNONE_H