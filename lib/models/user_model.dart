class UserModel {
  final String uid;
  final String? email;
  final String? phoneNumber;

  UserModel({
    required this.uid,
    this.email,
    this.phoneNumber,
  });

  factory UserModel.fromFirebaseUser(dynamic user) {
    return UserModel(
      uid: user.uid,
      email: user.email,
      phoneNumber: user.phoneNumber,
    );
  }
}

