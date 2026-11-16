// Minimal declarations for the read-only subset of libarchive used by ArchiveCore.
// macOS ships /usr/lib/libarchive.dylib but the SDK has no headers for it.
// Signatures match libarchive 3.x (archive.h / archive_entry.h).

#ifndef CARCHIVE_H
#define CARCHIVE_H

#include <stdint.h>
#include <sys/types.h>
#include <time.h>

#define ARCHIVE_EOF       1
#define ARCHIVE_OK        0
#define ARCHIVE_RETRY   (-10)
#define ARCHIVE_WARN    (-20)
#define ARCHIVE_FAILED  (-25)
#define ARCHIVE_FATAL   (-30)

#define AE_IFMT   ((mode_t)0170000)
#define AE_IFREG  ((mode_t)0100000)
#define AE_IFLNK  ((mode_t)0120000)
#define AE_IFDIR  ((mode_t)0040000)

struct archive;
struct archive_entry;

int archive_version_number(void);

struct archive *archive_read_new(void);
int archive_read_support_filter_all(struct archive *);
int archive_read_support_format_all(struct archive *);
int archive_read_support_format_raw(struct archive *);
int archive_read_open_filename(struct archive *, const char *filename, size_t block_size);
int archive_read_next_header(struct archive *, struct archive_entry **);
int archive_read_data_skip(struct archive *);
int archive_read_free(struct archive *);

const char *archive_error_string(struct archive *);
const char *archive_format_name(struct archive *);
int archive_filter_count(struct archive *);
const char *archive_filter_name(struct archive *, int);

const char *archive_entry_pathname(struct archive_entry *);
const char *archive_entry_pathname_utf8(struct archive_entry *);
int64_t archive_entry_size(struct archive_entry *);
int archive_entry_size_is_set(struct archive_entry *);
mode_t archive_entry_filetype(struct archive_entry *);
time_t archive_entry_mtime(struct archive_entry *);
int archive_entry_mtime_is_set(struct archive_entry *);
int archive_entry_is_encrypted(struct archive_entry *);

#endif
