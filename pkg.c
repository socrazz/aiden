#include <dirent.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>

#define LIB_PKG_align 16
#define LIB_PKG_base 64
#define LIV_PKG_length 3
#define LIB_PKG_magic 0x474B5023
#define LIB_PKG_name_limit 40
#define LIB_PKG_shift 6

struct LIB_PKG_STRUCTURE {
    uint64_t offset;
    uint64_t size;
    uint64_t length;
    uint8_t name[LIB_PKG_name_limit];
};

int main() {
    // prepare empty file header
    struct LIB_PKG_STRUCTURE pkg[LIB_PKG_BASE] = { 0 };

    // include 
    uint64_t files_included = 0;

    // directory entry
    struct dirent *entry = NULL;

    // open directory content
    DIR *directory = opendir("system");

    while ((entry = readdir(directory)) != NULL) {
        if (!strcmp(entry -> d_name, ".") || !strcmp(entry -> d_name, ".."))
            continue;
    }
}