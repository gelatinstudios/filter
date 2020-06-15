
T square(T)(T x) {
    return x*x;
}

T clamp_lower(T)(T x, T min) {
    if (x < min) return  min;
    return x;
}

T clamp_upper(T)(T x, T max) {
    if (x > max) return  max;
    return x;
}

T clamp(T)(T min, T x, T max) {
    return clamp_upper(clamp_lower(x, min), max);
}

T clamp(T)(T min, T *x, T max) {
    return *x = clamp_upper(clamp_lower(*x, min), max);
}

float gauss(float x, float y, float stdev) {
    import std.math : exp, PI;
    float result = 1.0f / (2*PI*square(stdev));
    result *= exp(-(square(x) + square(y)) / (2*square(stdev)));
    return result;
}
