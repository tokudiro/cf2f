#ifndef SBUF_H__
#define SBUF_H__
typedef struct SBuf_struct SBuf;
SBuf* SBuf_init(SBuf* pthis) ;
void SBuf_setText(SBuf* pthis, const char* top, const int len);
const char* SBuf_getText(const SBuf* pthis);
int SBuf_getLen(const SBuf* pthis);
char SBuf_isExist(const SBuf* pthis);
#endif /* SBUF_H__ */
