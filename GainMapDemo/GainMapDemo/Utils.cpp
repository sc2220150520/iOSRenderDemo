//
//  Utils.cpp
//  GainMapDemo
//
//  Created by Chang on 2024/2/15.
//

#include "Utils.h"

#include <cstdio>
#include <cstdarg>
#include <cstring>
#include <memory>

// Custom log function
//void Nlog(const char* format, ...) {
//    // Calculate the length of the format string plus 2 for the newline and null terminator
//    size_t len = strlen(format) + 2;
//    
//    // Allocate a new string on the heap to hold the modified format string
//    std::unique_ptr<char[]> newFormat(new char[len]);
//    
//    // Copy the original format string and append a newline character at the end
//    snprintf(newFormat.get(), len, "%s\n", format);
//    
//    // Initialize the va_list and use vprintf with the new format string
//    va_list args;
//    va_start(args, format);
//    vprintf(newFormat.get(), args);
//    va_end(args);
//}

void NLogImpl(const char* file, int line, const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);

    const char* file_name = file;
    const char* last_slash = strrchr(file, '/');
    if (last_slash != NULL) {
        file_name = last_slash + 1;  // Return the substring after the last slash
    }

    // Create a new format string that includes the file and line information
    char new_fmt[1024];
    snprintf(new_fmt, sizeof(new_fmt), "%s:%d: %s\n", file_name, line, fmt);

    vprintf(new_fmt, args);

    va_end(args);
}
