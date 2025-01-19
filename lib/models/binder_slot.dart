import './photocard.dart';

class BinderSlot {
  final String slotId;
  Photocard? photocard;

  BinderSlot({
    required this.slotId,
    this.photocard,
  });

  Map<String, dynamic> toMap() {
    return {
      'slotId': slotId,
      'instanceId': photocard?.instanceId,
    };
  }
}
