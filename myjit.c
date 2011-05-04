#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <stdint.h>

#include <assert.h>
#include <sys/nacl_syscalls.h>
#include <sys/mman.h>
#include <unistd.h>

extern char etext[];

#if defined(__x86_64__)
/* On x86-64, template functions do not fit in 32-byte buffers */
#define BUF_SIZE 64
#elif defined(__i386__) || defined(__arm__)
#define BUF_SIZE 32
#else
#error "Unknown Platform"
#endif

#if defined(__i386__) || defined(__x86_64__)
#define NACL_BUNDLE_SIZE  32
#elif defined(__arm__)
#define NACL_BUNDLE_SIZE  16
#else
#error "Unknown Platform"
#endif

#define DYNAMIC_CODE_SEGMENT_START (((((uint32_t)etext) + 0x10000 + 0xFFFF) / 0x10000) * 0x10000)
#define DYNAMIC_CODE_SEGMENT_END   0x00070000 /* the number specified in the Makefile for rodata start */

static char *next_addr;

int nacl_load_code(void *dest, void *src, int size) {
  int rc = nacl_dyncode_create(dest, src, size);
  /* Undo the syscall wrapper's errno handling, because it's more
     convenient to test a single return value. */
  return rc == 0 ? 0 : -errno;
}

char *allocate_code_space(int pages) {
  char *addr = next_addr;
  next_addr += 0x10000 * pages;
  assert(next_addr < (char *) DYNAMIC_CODE_SEGMENT_END);
  return addr;
}

void fill_nops(uint8_t *data, size_t size) {
#if defined(__i386__) || defined(__x86_64__)
  memset(data, 0x90, size); /* NOPs */
#elif defined(__arm__)
  fill_int32(data, size, 0xe1a00000); /* NOP (MOV r0, r0) */
#else
# error "Unknown arch"
#endif
}

void fill_hlts(uint8_t *data, size_t size) {
#if defined(__i386__) || defined(__x86_64__)
  memset(data, 0xf4, size); /* HLTs */
#elif defined(__arm__)
  fill_int32(data, size, 0xe1266676); /* BKPT 0x6666 */
#else
# error "Unknown arch"
#endif
}

void copy_and_pad_fragment(void *dest,
                           int dest_size,
                           const char *fragment_start,
                           const char *fragment_end) {
  int fragment_size = fragment_end - fragment_start;
  assert(dest_size % NACL_BUNDLE_SIZE == 0);
  assert(fragment_size <= dest_size);
  fill_nops(dest, dest_size);
  memcpy(dest, fragment_start, fragment_size);
}

int foo() 
{
  return 1234; 
}

int
main(int ac, char *av[])
{
  int rc;
  uint8_t buf[32];
  void *load_area;
  int (*func)();

  next_addr = (char *) DYNAMIC_CODE_SEGMENT_START;
  load_area = allocate_code_space(1);
  copy_and_pad_fragment(buf, sizeof(buf), (const char*)foo, (const char *)(foo+15));

  rc = nacl_load_code(load_area, buf, sizeof(buf));
  assert(rc == 0);
  assert(memcmp(load_area, buf, sizeof(buf)) == 0);

  func = (int (*)()) (uintptr_t)load_area;
  rc = func();
  fprintf(stderr, "Hello World! %d", rc);
  return 0;
}

