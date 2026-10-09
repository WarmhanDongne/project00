/// Packages with executable regression suites in the release candidate.
/// game_template is a skeleton with no tests; it is not counted as a test pass.
const packageTestTargets = <PackageTestTarget>[
  PackageTestTarget('game_kit'),
  PackageTestTarget('game_liars_poker'),
  PackageTestTarget('game_final_call'),
  PackageTestTarget('game_mafia'),
  PackageTestTarget('game_holdem'),
];

final class PackageTestTarget {
  const PackageTestTarget(this.name);

  final String name;
  String get directory => 'packages/$name';
  String get stepId => 'flutter-test-${name.replaceAll('_', '-')}';
}
