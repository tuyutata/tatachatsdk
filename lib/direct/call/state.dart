enum DirectCallPhase { incoming, calling, connecting, connected, ended, failed }

class DirectCallState {
  const DirectCallState(this.phase, {this.reason});
  final DirectCallPhase phase;
  final String? reason;

  bool get isTerminal =>
      phase == DirectCallPhase.ended || phase == DirectCallPhase.failed;
}
