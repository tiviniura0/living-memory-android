class LifecyclePause {
  final void Function(bool) setPaused;
  final Future<void> Function() save;
  LifecyclePause(this.setPaused, this.save);
  Future<void> background() async {
    setPaused(true);
    await save();
  }

  void resume() {
    /* Explicit user resume only; no elapsed background time. */
  }
}
