class OptionStrike {
  const OptionStrike({
    required this.strike,
    this.callToken,
    this.putToken,
  });

  final double strike;
  final String? callToken;
  final String? putToken;

  List<String> get tokens => [
        ?callToken,
        ?putToken,
      ];
}
