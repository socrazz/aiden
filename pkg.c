#include <dirent.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>

#define LIB_PKG_length 4
#define LIB_PKG_magic "#PKG"
#define LIB_PKG_base 64
#define LIB_PKG_align 16
#define LIB_PKG_name_limit 40

struct LIB_PKG_STRUCTURE {
    uint64_t offset;
    uint64_t size;
    uint64_t length;
    uint8_t name[LIB_PKG_name_limit];
};

int main() {
    // creating empty file header
    struct LIB_PKG_STRUCTURE pkg[LIB_PKG_base] = { 0 };
}