{{flutter_js}}
{{flutter_build_config}}

// Give the renamed app a fresh entrypoint URL instead of reusing a cached
// bundle from the previous brand. Keep preview builds free of service workers.
for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath) {
    build.mainJsPath += '?v=everlane-1';
  }
}
_flutter.loader.load();
