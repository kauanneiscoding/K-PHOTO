import 'package:uuid/uuid.dart';

String generateUniqueId() {
  var uuid = Uuid();
  return uuid.v4(); // Gera um ID único
}
