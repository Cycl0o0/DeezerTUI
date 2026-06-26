/* Thin main() for the standalone opendeezer-gnome executable. The real entry is
 * opendeezer_run() in main.c (also exported from libopendeezer-gtk.so for the
 * unified Linux launcher). */
int opendeezer_run(int argc, char **argv);

int main(int argc, char **argv) { return opendeezer_run(argc, argv); }
