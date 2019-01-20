#include <string.h>

/**
* @class SBuf
* @brief String Buffer
*/
#include "SBuf.h"
#include "SBuf_define.h"

/**
* @brief initial
* @memeberof SBuf
*/
SBuf* SBuf_init(SBuf* pthis) {
	memset(&(pthis->str[0]), 0, MAX_TEXT);
	pthis->exist = 0;
	pthis->len = 0;
	return pthis;
}

/**
* @brief set String
* @memeberof SBuf
*/
void SBuf_setText(SBuf* pthis, const char* top, const int len) {
	SBuf_init(pthis);
	strncpy(pthis->str, top, len);
	pthis->len = len;
	pthis->exist = 1;
}

/**
* @brief get String
* @memeberof SBuf
*/
const char* SBuf_getText(const SBuf* pthis) {
	return pthis->str;
}

/**
* @brief get Length
* @memeberof SBuf
*/
int SBuf_getLen(const SBuf* pthis) {
	return pthis->len;
}

/**
* @brief exist?
* @memberof SBuf
*/
char SBuf_isExist(const SBuf* pthis) {
	return pthis->exist;
}
