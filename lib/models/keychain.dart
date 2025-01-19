class Keychain {
  final String id;
  final String imagePath;
  final double size;

  const Keychain({
    required this.id,
    required this.imagePath,
    this.size = 50.0,
  });
}
