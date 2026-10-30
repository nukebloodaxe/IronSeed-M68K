/* Fast stars (Phase 6m): the model of utils2.s u2_walkf - readystar's three walks on a cheap
 * generator (additive lagged Fibonacci on longs, lags 24/55, one byte a step: 252 values in 9
 * steps of 28, 4 = stay). Usage:
 *   faststar land SEED MODE OUT.BIN   landform (28800 bytes, [x][y], x 1..240 major) as the ST
 *   faststar scan [FROM TO]           every key: the largest count of one cell in one walk
 *                                     (u2_pmap's counts must stay below 128) */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#define NB 2048
static uint32_t buf[55 + NB];
static int avail, pos;           /* bytes left in the block, byte position */
static long ci;                  /* utils2's i (the countdown's 1125 steps): goes on across walks */
static void seedf(uint32_t key) {
    uint32_t s = key;
    for (int i = 0; i < 55; i++) { s = s * 69069u + 1u; buf[i] = s; }
    buf[0] |= 1; avail = 0; ci = 0;
}
static void block(void) {
    for (int i = 55; i < 55 + NB; i++) buf[i] = buf[i - 24] + buf[i - 55];
    /* the bytes of buf[55..] big-endian; then the last 55 to the front (after use) */
    avail = NB * 4; pos = 0;
}
static uint8_t outb[NB * 4];
static void block2(void) {
    block();
    for (int i = 0; i < NB; i++) { uint32_t v = buf[55 + i];
        outb[4*i] = v >> 24; outb[4*i+1] = v >> 16; outb[4*i+2] = v >> 8; outb[4*i+3] = v; }
    memmove(buf, buf + NB, 55 * 4);
}
static int cnt[242][122];
static int walk(int x, int y, uint8_t *cmap) {   /* returns the largest count */
    long left = 75000, i = ci; int mx = 0;
    memset(cnt, 0, sizeof cnt);
    while (left > 0) {
        long n = 1125 - i; if (n > left) n = left;
        left -= n; i += n;
        if (avail < n) block2();
        for (long k = 0; k < n; k++) {
            int b = outb[pos++]; avail--;
            if (b < 252) { int d = b / 28; x += d / 3 - 1; y += d % 3 - 1;
                if (x == 0) x = 240; else if (x == 241) x = 1;
                if (y == 0) y = 120; else if (y == 121) y = 1; }
            if (++cnt[x][y] > mx) mx = cnt[x][y];
        }
        if (i == 1125) i = 0;
    }
    ci = i;
    if (cmap) for (x = 1; x <= 240; x++) for (y = 1; y <= 120; y++) cmap[(x-1)*120 + y-1] += cnt[x][y];
    return mx;
}
int main(int argc, char **argv) {
    static const int sx[3] = {200, 30, 120}, sy[3] = {90, 30, 60};
    static const int col[3] = {120, 83, 16};
    if (argc >= 5 && !strcmp(argv[1], "land")) {
        uint32_t seed = strtoul(argv[2], 0, 0), mode = strtoul(argv[3], 0, 0);
        static uint8_t land[28800]; uint8_t c = col[mode - 1] + 6;
        memset(land, col[mode - 1], sizeof land);
        seedf(seed | mode << 16);
        for (int w = 0; w < 3; w++) {
            static uint8_t cm[28800]; memset(cm, 0, sizeof cm);
            walk(sx[w], sy[w], cm);
            for (int j = 0; j < 28800; j++) for (int v = cm[j]; v > 0 && land[j] < c; v--) land[j]++;
        }
        FILE *f = fopen(argv[4], "wb"); fwrite(land, 1, sizeof land, f); fclose(f);
        return 0;
    }
    if (argc >= 2 && !strcmp(argv[1], "scan")) {
        long from = argc > 2 ? atol(argv[2]) : 0, to = argc > 3 ? atol(argv[3]) : 65536 * 3;
        int worst = 0;
        for (long k = from; k < to; k++) {
            uint32_t seed = k % 65536, mode = k / 65536 + 1;
            seedf(seed | mode << 16);
            for (int w = 0; w < 3; w++) { int m = walk(sx[w], sy[w], 0);
                if (m > worst) { worst = m; printf("key %ld walk %d max %d\n", k, w, m); fflush(stdout); } }
        }
        printf("worst %d\n", worst);
        return 0;
    }
    return 1;
}
