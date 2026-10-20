/// A small token source for async screen loads where only the latest request
/// may update visible state.
class RequestGeneration {
  int _value = 0;

  int begin() => ++_value;

  bool isCurrent(int generation) => generation == _value;
}
