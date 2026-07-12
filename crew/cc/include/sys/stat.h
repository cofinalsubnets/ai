#ifndef _AI_SYS_STAT_H
#define _AI_SYS_STAT_H
#include <time.h>   /* struct timespec */
/* glibc x86-64 struct stat: 144 bytes, st_nlink BEFORE st_mode (the classic) */
struct stat {
  unsigned long st_dev;
  unsigned long st_ino;
  unsigned long st_nlink;
  unsigned int  st_mode;
  unsigned int  st_uid;
  unsigned int  st_gid;
  int           __pad0;
  unsigned long st_rdev;
  long          st_size;
  long          st_blksize;
  long          st_blocks;
  struct timespec st_atim;
  struct timespec st_mtim;
  struct timespec st_ctim;
  long __reserved[3];
};
#define S_IFMT   61440
#define S_IFSOCK 49152
#define S_IFLNK  40960
#define S_IFREG  32768
#define S_IFBLK  24576
#define S_IFDIR  16384
#define S_IFCHR   8192
#define S_IFIFO   4096
#define S_ISREG(m)  (((m) & S_IFMT) == S_IFREG)
#define S_ISDIR(m)  (((m) & S_IFMT) == S_IFDIR)
#define S_ISLNK(m)  (((m) & S_IFMT) == S_IFLNK)
#define S_ISCHR(m)  (((m) & S_IFMT) == S_IFCHR)
#define S_ISFIFO(m) (((m) & S_IFMT) == S_IFIFO)
#define S_ISSOCK(m) (((m) & S_IFMT) == S_IFSOCK)
#define UTIME_NOW  1073741823
#define UTIME_OMIT 1073741822
int stat(char const*, struct stat*);
int fstat(int, struct stat*);
int lstat(char const*, struct stat*);
int mkdir(char const*, unsigned int);
int chmod(char const*, unsigned int);
int fchmod(int, unsigned int);
unsigned int umask(unsigned int);
int utimensat(int, char const*, struct timespec const*, int);
int mkfifo(char const*, unsigned int);
int mknod(char const*, unsigned int, unsigned long);
#endif
