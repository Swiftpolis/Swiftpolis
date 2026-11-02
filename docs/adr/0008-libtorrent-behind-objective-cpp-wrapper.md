# libtorrent sits behind a small Objective-C++ wrapper

libtorrent is built from source for Apple silicon, linked statically and reached only through a small Objective-C++ wrapper, not through Swift's C++ interop. Its headers lean heavily on Boost and templates, and keeping them out of Swift limits build problems to one file. Static linking means the app doesn't depend on Homebrew being installed.
