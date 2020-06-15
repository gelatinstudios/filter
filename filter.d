
import std.stdio;

import math;
import vector_math;
import image;

void median_filter(image im, int radius) {
    import std.algorithm : sort;
    
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

void gaussian_blur(image im, float stddev) {
    import std.math : ceil;
    
    writeln("using gaussian blur with a stddev of ", stddev);
    
    int radius = (cast(int)ceil(6*stddev))/2 - 1; // ??????
    
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

enum method_type {
    median,
    gauss,
}

struct cmd_options {
    int png_comp_level = 8;
    int radius  = 1;
    int jpg_quality = 100;
    float stddev = 3;
    method_type method;
}

void filter(image im, cmd_options cmd) {
    import core.stdc.stdlib : EXIT_FAILURE, exit;
    
    switch (cmd.method) {
        case method_type.median: im.median_filter(cmd.radius); break;
        case method_type.gauss:  im.gaussian_blur(cmd.stddev); break;
        
        default: {
            writeln("unknown filter method", cmd.method);
            exit(EXIT_FAILURE);
        }
    }
}

extern extern (C) int stbi_write_png_compression_level;

int main(string[] args) {
    import core.stdc.stdlib : EXIT_SUCCESS, EXIT_FAILURE, exit;
    import std.path : extension;
    import jt_cmd;
    
    bool check_extension(string filename) {
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