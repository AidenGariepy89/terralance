#include "terra_math.h"
#include "raylib.h"
#include "raymath.h"

#include <cassert>
#include <cmath>
#include <cstdio>

#include <random>


// Random


int Random::gen_int(int min, int max) {
    return std::uniform_int_distribution<>{min, max}(_gen);
}


// PerlinNoise


PerlinNoise::PerlinNoise(Random &random) {
    for (int i = 0; i < 256; ++i) {
        _permutations[i] = (uint8_t)i;
    }

    // shuffle
    for (int i = 0; i < 256; ++i) {
        int j = 255 - i;
        int temp = _permutations[j];
        int idx = random.gen_int(0, j);
        _permutations[j] = _permutations[idx];
        _permutations[idx] = temp;
    }

    // double
    for (int i = 0; i < 256; ++i) {
        _permutations[i + 256] = _permutations[i];
    }
}

float PerlinNoise::fbm(float x, float y, int octaves) {
    float result = 0.0f;
    float frequency = 1.0f;
    float amplitude = 0.005f;

    for (int i = 0; i < octaves; i++) {
        result += amplitude * noise_2d(x * frequency, y * frequency);

        amplitude *= 0.5;
        frequency *= 2;
    }

    assert(result >= -1 && result <= 1);

    return result;
}

float PerlinNoise::noise_2d(float x, float y) {
    float x_wrapped = fmod(x, 256);
    float y_wrapped = fmod(y, 256);

    int sector_x = (int)x_wrapped;
    int sector_y = (int)y_wrapped;

    float x_f = x_wrapped - trunc(x_wrapped);
    float y_f = y_wrapped - trunc(y_wrapped);

    Vector2 r_top_left     = Vector2{x_f, y_f};
    Vector2 r_top_right    = Vector2{x_f - 1.0f, y_f};
    Vector2 r_bottom_left  = Vector2{x_f, y_f - 1.0f};
    Vector2 r_bottom_right = Vector2{x_f - 1.0f, y_f - 1.0f};

    uint8_t hash_top_left     = _permutations[_permutations[sector_x]                + sector_y];
    uint8_t hash_top_right    = _permutations[_permutations[inc_with_wrap(sector_x)] + sector_y];
    uint8_t hash_bottom_left  = _permutations[_permutations[sector_x]                + inc_with_wrap(sector_y)];
    uint8_t hash_bottom_right = _permutations[_permutations[inc_with_wrap(sector_x)] + inc_with_wrap(sector_y)];
    Vector2 c_top_left     = perm_hash(hash_top_left);
    Vector2 c_top_right    = perm_hash(hash_top_right);
    Vector2 c_bottom_left  = perm_hash(hash_bottom_left);
    Vector2 c_bottom_right = perm_hash(hash_bottom_right);

    float dot_top_left     = Vector2DotProduct(r_top_left, c_top_left);
    float dot_top_right    = Vector2DotProduct(r_top_right, c_top_right);
    float dot_bottom_left  = Vector2DotProduct(r_bottom_left, c_bottom_left);
    float dot_bottom_right = Vector2DotProduct(r_bottom_right, c_bottom_right);

    float u = ease(x_f);
    float v = ease(y_f);

    float result = Lerp(
        Lerp(dot_top_left, dot_bottom_left, v),
        Lerp(dot_top_right, dot_bottom_right, v),
        u
    );

    assert(result >= -1 && result <= 1);

    return result;
}

int PerlinNoise::inc_with_wrap(int x) {
    return (x + 1) % 256;
}

Vector2 PerlinNoise::perm_hash(uint8_t hash) {
    switch (hash % 4) {
        case (0):
            return Vector2{1, 1};
        case (1):
            return Vector2{1, -1};
        case (2):
            return Vector2{-1, 1};
        case (3):
            return Vector2{-1, -1};
        default:
            assert(false);
    }
}

float PerlinNoise::ease(float x) {
    return x * x * x * (x * (6.0f * x - 15.0f) + 10.0f);
}
