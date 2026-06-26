// Thin main() for the standalone opendeezer-kde executable. The real entry is
// opendeezer_run() in main.cpp (also exported from libopendeezer-qt.so for the
// unified Linux launcher).
extern "C" int opendeezer_run(int argc, char **argv);

int main(int argc, char **argv) { return opendeezer_run(argc, argv); }
