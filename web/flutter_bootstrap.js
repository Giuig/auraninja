{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const engine = await engineInitializer.initializeEngine();
    if (window.ninjaLoader) window.ninjaLoader.hide();
    await engine.runApp();
  }
});
