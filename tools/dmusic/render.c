// Offline renderer: DirectMusic segment -> WAV. Test harness only.
#include <dmusic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

// Longest audio rendered for any one segment, in seconds.
#define MAX_SECONDS 120

static void* resolve(void* ctx, char const* name, size_t* len) {
	// OpenAvP2 extracts with canonicalised lowercase names, while segments
	// reference their banks in the original mixed case. On a case-sensitive
	// filesystem the lookup must be normalised or every bank misses.
	char lowered[1024];
	size_t n = strlen(name);
	if (n >= sizeof lowered) n = sizeof lowered - 1;
	for (size_t i = 0; i < n; i++) {
		char c = name[i];
		lowered[i] = (c >= 'A' && c <= 'Z') ? (char)(c - 'A' + 'a') : c;
	}
	lowered[n] = '\0';

	char path[2048];
	snprintf(path, sizeof path, "%s/%s", (char*)ctx, lowered);
	FILE* f = fopen(path, "rb");
	if (!f) { fprintf(stderr, "  [miss] %s\n", lowered); return NULL; }
	struct stat st; stat(path, &st);
	void* buf = malloc(st.st_size);
	*len = fread(buf, 1, st.st_size, f);
	fclose(f);
	fprintf(stderr, "  [load] %s (%zu bytes)\n", lowered, *len);
	return buf;
}

static void put32(FILE* f, unsigned v){fputc(v&255,f);fputc(v>>8&255,f);fputc(v>>16&255,f);fputc(v>>24&255,f);}
static void put16(FILE* f, unsigned v){fputc(v&255,f);fputc(v>>8&255,f);}

int main(int argc, char** argv) {
	if (argc < 4) { puts("usage: render <dir> <segment.sgt> <out.wav> [seconds]"); return 2; }
	double override_seconds = argc > 4 ? atof(argv[4]) : 0.0;
	const int RATE = 44100, CH = 2;

	Dm_setLoggerDefault(DmLogLevel_WARN);

	DmLoader* loader = NULL;
	if (DmLoader_create(&loader, DmLoader_DEFAULT) != DmResult_SUCCESS) return 1;
	if (DmLoader_addResolver(loader, resolve, argv[1]) != DmResult_SUCCESS) return 1;

	DmSegment* seg = NULL;
	DmResult rv = DmLoader_getSegment(loader, argv[2], &seg);
	if (rv != DmResult_SUCCESS) { printf("FAILED to load segment: rv=%d\n", rv); return 1; }
	printf("segment loaded OK\n");

	// Download instruments explicitly; a partial failure is tolerated so that we
	// can hear how much of the score binds correctly.
	rv = DmSegment_download(seg, loader);
	printf("instrument download: rv=%d (%s)\n", rv, rv == DmResult_SUCCESS ? "ok" : "partial/failed");

	// Render the segment's own length, plus a short tail so reverb and releases
	// are not cut off mid-decay.
	// Some segments report an effectively infinite length, a sentinel for "loop
	// until told otherwise" rather than a real duration. Rendering that verbatim
	// would try to allocate days of audio, so cap it: a looping segment only
	// needs enough material for the runtime to loop.
	double length = DmSegment_getLength(seg);
	double seconds = override_seconds > 0.0 ? override_seconds : length + 2.0;
	if (seconds > MAX_SECONDS) {
		printf("segment reports %.0fs, capping at %.0fs (looping segment)\n", length, (double) MAX_SECONDS);
		seconds = MAX_SECONDS;
	} else {
		printf("segment length: %.2fs, rendering %.2fs\n", length, seconds);
	}

	DmPerformance* perf = NULL;
	if (DmPerformance_create(&perf, RATE) != DmResult_SUCCESS) return 1;
	if (DmPerformance_playSegment(perf, seg, DmTiming_INSTANT) != DmResult_SUCCESS) return 1;

	size_t frames = (size_t)(RATE * seconds);
	size_t samples = frames * CH;
	short* pcm = calloc(samples, sizeof(short));
	rv = DmPerformance_renderPcm(perf, pcm, samples, DmRender_SHORT | DmRender_STEREO);
	if (rv != DmResult_SUCCESS) { printf("FAILED to render: rv=%d\n", rv); return 1; }

	long nonzero = 0; long peak = 0;
	for (size_t i = 0; i < samples; i++) { if (pcm[i]) nonzero++; long a = pcm[i]<0?-pcm[i]:pcm[i]; if (a>peak) peak=a; }
	printf("rendered %zu samples, %ld non-silent (%.1f%%), peak=%ld\n",
	       samples, nonzero, 100.0*nonzero/samples, peak);

	FILE* out = fopen(argv[3], "wb");
	unsigned dataBytes = samples * 2;
	fwrite("RIFF",1,4,out); put32(out, 36+dataBytes); fwrite("WAVE",1,4,out);
	fwrite("fmt ",1,4,out); put32(out,16); put16(out,1); put16(out,CH);
	put32(out,RATE); put32(out,RATE*CH*2); put16(out,CH*2); put16(out,16);
	fwrite("data",1,4,out); put32(out,dataBytes);
	fwrite(pcm,2,samples,out); fclose(out);
	printf("wrote %s\n", argv[3]);
	// A segment that renders silent is a valid result, not a failure: the score
	// uses explicit silence states.
	return 0;
}
