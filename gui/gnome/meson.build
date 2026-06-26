# OpenDeezer — native GNOME (GTK4 + libadwaita) front-end.
#
# The Go engine archive (lib/libdeezercore.a + lib/libdeezercore.h) must already
# exist before configuring: build.sh builds it first, then runs meson. The
# archive is a Linux cgo c-archive that statically links the Go runtime and
# dynamically links ALSA (via ebitengine/oto), so the final link needs
# -lasound -lpthread -ldl -lm AFTER the archive (left-to-right resolution).

project('opendeezer-gnome', 'c',
  version: '1.0.0',
  meson_version: '>=0.59.0',
  default_options: ['c_std=c11', 'warning_level=1'])

deps = [
  # gtk_picture_set_content_fit is 4.8+; CSS string loader guarded for 4.12.
  dependency('gtk4', version: '>=4.10'),
  # AdwNavigationSplitView/AdwToolbarView are 1.4; AdwAboutDialog is 1.5.
  dependency('libadwaita-1', version: '>=1.5'),
  dependency('json-glib-1.0'),
]

# Prebuilt Go engine archive + its generated header.
core_archive = meson.current_source_dir() / 'lib' / 'libdeezercore.a'
dzcore = declare_dependency(
  link_args: [core_archive, '-lasound', '-lpthread', '-ldl', '-lm'],
  include_directories: include_directories('lib'),
)

executable('opendeezer-gnome',
  'src/main.c',
  dependencies: deps + [dzcore],
  install: true)

install_data('data/org.opendeezer.OpenDeezer.desktop',
  install_dir: get_option('datadir') / 'applications')
