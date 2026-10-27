class WorldRng {
  int state;
  WorldRng(this.state) {
    if (state < 1 || state > 0xffffffff)
      throw ArgumentError('Seed must be nonzero uint32');
  }
  int nextUint32() {
    var x = state;
    x ^= (x << 13) & 0xffffffff;
    x ^= x >> 17;
    x ^= (x << 5) & 0xffffffff;
    return state = x & 0xffffffff;
  }
}
