
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

struct v4 {
    union {
        struct { float x, y, z, w; };
        struct { float r, g, b, a; };
    }
    
    v4 opBinary(string op)(v4 l) if (op == "+" || op == "-") {
        mixin("return v4(x" ~ op ~ "l.x, y" ~ op ~ "l.y, z" ~ op ~ "l.z, w" ~ op ~ "l.w);");
    }
    
    v4 opBinary(string op)(float f) if (op == "*") {
        return v4(f*x, f*y, f*z, f*w);
    }
    
    v4 opBinaryRight(string op)(float f) if (op == "*") {
        return opBinary!op(f);
    }
    
    v4 opOpAssign(string op,T)(T l) {
        return this = this.opBinary!op(l);
    }
}

v4 lerp(v4 a, float t, v4 b) {
    return (1.0f - t)*a + t*b;
}

uint v4_to_rgba(v4 v) {
    import std.math : lrint;
    
    uint result = 0;
    result |= (lrint(v.r));
    result |= (lrint(v.g) << 8);
    result |= (lrint(v.b) << 16);
    result |= (lrint(v.a) << 24);
    return result;
}

v4 rgba_to_v4(uint u) {
    v4 result;
    result.r = cast(ubyte) (u);
    result.g = cast(ubyte) (u >> 8);
    result.b = cast(ubyte) (u >> 16);
    result.a = cast(ubyte) (u >> 24);
    return result;
}

ubyte rgba_get_alpha(uint p) {
    return cast(ubyte) (p >> 24);
}

float get_value(v4 v) {
    import std.algorithm : max;
    return max(v.r, v.g, v.b);
}


float get_value(uint p) {
    __gshared float[1<<24] rgb_value_memo;
    
    float *ptr = &rgb_value_memo[p & 0x00ffffff];
    if (*ptr) return *ptr;
    
    float result = get_value(rgba_to_v4(p));
    *ptr = result;
    return result;
}

uint rgba_2_average(uint a, uint b) {
    return lerp(a.rgba_to_v4, 0.5f, b.rgba_to_v4).v4_to_rgba;
}

struct image {
    int width;
    int height;
    uint *pixels;
}

uint get_pixel(image im, int x, int y) {
    assert(x >= 0 && x < im.width && y >= 0 && y < im.height);
    return *(im.pixels + im.width*y + x);
}

extern (C) ubyte *stbi_load(const char *filename, int *w, int *h, int *channels_in_file, int desired_channels);

image load_image(string filename) {
    import std.string : toStringz;
    
    image result;
    result.pixels = cast(uint *) stbi_load(filename.toStringz, &result.width, &result.height, null, 4);
    return result;
}

extern (C) int stbi_write_png(const char *filename, int w, int h, int comp, const void *data, int stride_in_bytes);
extern (C) int stbi_write_bmp(const char *filename, int w, int h, int comp, const void *data);
extern (C) int stbi_write_tga(const char *filename, int w, int h, int comp, const void *data);
extern (C) int stbi_write_jpg(const char *filename, int w, int h, int comp, const void *data, int quality);

void write_out_image(image im, string filename, int jpg_quality) {
    import std.string : toStringz;
    import std.path : extension;
    import std.stdio : writeln;
    
    const auto ext = filename.extension;
    switch (ext) {
        case ".png": stbi_write_png(filename.toStringz, im.width, im.height, 4, im.pixels, 0);           break;
        case ".bmp": stbi_write_bmp(filename.toStringz, im.width, im.height, 4, im.pixels);              break;
        case ".jpg": stbi_write_jpg(filename.toStringz, im.width, im.height, 4, im.pixels, jpg_quality); break;
        case ".tga": stbi_write_tga(filename.toStringz, im.width, im.height, 4, im.pixels);              break;
        
        default: assert(0);
    }
}

void median_filter(image im, int radius) {
    import std.algorithm : sort;
    import std.stdio : writeln;
    
    writeln("using median filter with radius of ", radius);
    
    uint[] window;
    window.reserve(square(radius*2 + 1));
    
    uint *dest = im.pixels;
    foreach (y; 0 .. im.height) {
        foreach (x; 0 .. im.width) {
            window.length = 0;
            window.assumeSafeAppend;
            
            const wx_end = clamp(0, x+radius+1, im.width-1);
            const wy_end = clamp(0, y+radius+1, im.height-1);
            
            foreach (wy; clamp(0, y-radius, im.height-1) .. wy_end) {
                foreach (wx; clamp(0, x-radius, im.width-1) .. wx_end) {
                    window ~= im.get_pixel(wx, wy);
                }
            }
            
            // TODO: implement insertion sort
            uint output;
            window.sort!((a,b) => a.get_value < b.get_value);
            if (window.length & 1) {
                output = window[$/2];
            } else {
                output = rgba_2_average(window[$/2 - 1], window[$/2]);
            }
            
            *dest++ = output;
        }
    }
}

void gaussian_blur(image im, int stddev) {
    import std.stdio : writeln;
    
    writeln("using gaussian blur with a stddev of ", stddev);
    
    int radius = 6*stddev/2 - 1; // ??????
    
    uint *dest = im.pixels;
    foreach (y; 0 .. im.height) {
        foreach (x; 0 .. im.width) {
            const wx_end = clamp(0, x+radius+1, im.width-1);
            const wy_end = clamp(0, y+radius+1, im.height-1);
            
            v4 output = v4(0, 0, 0, 0);
            
            foreach (wy; clamp(0, y-radius, im.height-1) .. wy_end) {
                foreach (wx; clamp(0, x-radius, im.width-1) .. wx_end) {
                    auto p = im.get_pixel(wx, wy);
                    
                    output += gauss(wx - x, wy - y, stddev)*p.rgba_to_v4;
                }
            }
            
            *dest++ = output.v4_to_rgba;
        }
    }
}

struct cmd_options {
    int png_comp_level = 8;
    int radius  = 1;
    int jpg_quality = 100;
    int stddev = 3;
    string method = "median";
}

void filter(image im, cmd_options cmd) {
    import std.stdio : writeln;
    
    switch (cmd.method) {
        case "median": im.median_filter(cmd.radius); break;
        case "gauss":  im.gaussian_blur(cmd.stddev); break;
        
        default: writeln("unknown filter method", cmd.method); assert(0); // TODO: change to exit
    }
}

extern extern (C) int stbi_write_png_compression_level;

int main(string[] args) {
    import core.stdc.stdlib;
    import std.stdio;
    import std.path : extension;
    import jt_cmd;
    
    bool check_extension(string filename) {
        import std.path : extension;
        string ext = filename.extension;
        return (ext == ".png" ||
                ext == ".bmp" ||
                ext == ".jpg" ||
                ext == ".tga");
    }
    
    auto cmd = args.parse_commandline_arguments!cmd_options;
    stbi_write_png_compression_level = cmd.png_comp_level;
    
    string[] filenames;
    for (size_t i = 1; i < args.length; ++i) {
        const arg = args[i];
        if (arg[0] == '-') {
            ++i;
            continue;
        }
        filenames ~= arg;
    }
    
    if (filenames.length != 2) {
        writeln("usage: ", args[0], " [input filename] [output filename] -[option [arg]...]");
        return EXIT_FAILURE;
    }
    
    auto input  = filenames[0];
    auto output = filenames[1];
    
    image im = load_image(input);
    
    if (!im.pixels) {
        writeln("trouble loading file: ", input);
        return EXIT_FAILURE;
    }
    
    if (!check_extension(output)) {
        writeln("unknown extension: ", output.extension);
        return EXIT_FAILURE;
    }
    
    writeln("in: ", input); stdout.flush;
    
    im.filter(cmd);
    
    im.write_out_image(output, cmd.jpg_quality);
    writeln("out: ", output);
    
    return EXIT_SUCCESS;
}