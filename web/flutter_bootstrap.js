{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const engine = await engineInitializer.initializeEngine();
    // Arm before runApp, so the listeners are in place before the first
    // frame can fire. The loader dismisses itself once the app has
    // actually painted.
    if (window.ninjaLoader) window.ninjaLoader.dismissOnFirstFrame();
    await engine.runApp();
  }
});
