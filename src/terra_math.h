#ifndef TERRA_MATH_H
#define TERRA_MATH_H

#include "raylib.h"
#include <cstdint>
#include <random>


class Random {
    std::mt19937 _gen{std::random_device{}()};

public:
    Random() = default;
    Random(std::mt19937::result_type seed) : _gen(seed) {}

    int gen_int(int min, int max);
};


class PerlinNoise {
    uint8_t _permutations[512];

public:

    PerlinNoise(Random &rand);

    /// Fractal Brownian Motion
    float fbm(float x, float y, int octaves);
    float noise_2d(float x, float y);

private:
    int inc_with_wrap(int x);
    Vector2 perm_hash(uint8_t hash);
    float ease(float x);
};






/// Returns a percentage of the progress of val from min to max.
/// 
/// If val is less than min, returns 0.
/// If val is greater than max, returns 1.
float progress(float min, float max, float val);
/// Cubic bezier.
Vector2 cubic_bezier(Vector2 p0, Vector2 p1, Vector2 p2, Vector2 p3, float t);






#endif
