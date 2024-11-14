#include <cmath>
#include <cstdio>

#include "client.h"
#include "terra_math.h"

int main(void) {

    Random random;

    PerlinNoise noise{random};

    for (int i = 0; i < 100; ++i) {
        float y = fmod((float)i / 10.0f, 1.0f);
        printf("%f\n", y);
    }


    return 0;
}
