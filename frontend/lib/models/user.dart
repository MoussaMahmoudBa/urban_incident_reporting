class User {
  final int id;
  final String username;
  final String email;
  final String? phoneNumber;
  final String? profilePictureUrl;
  final String role;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.phoneNumber,
    this.profilePictureUrl,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0, // Valeur par défaut si null
      username: json['username']?.toString() ?? '', // Conversion et valeur par défaut
      email: json['email']?.toString() ?? '', // Conversion et valeur par défaut
      phoneNumber: json['phone_number']?.toString(), // Conversion en String si non null
      profilePictureUrl: json['profile_picture'] != null 
          ? 'http://127.0.0.1:8000${json['profile_picture']}'
          : null,
      role: json['role']?.toString() ?? 'citizen', // Conversion et valeur par défaut
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'phone_number': phoneNumber,
      'profile_picture': profilePictureUrl?.replaceFirst('http://127.0.0.1:8000', ''),
      'role': role,
    };
  }
}