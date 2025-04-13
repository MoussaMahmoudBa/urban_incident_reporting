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
      id: json['id'],
      username: json['username'],
      email: json['email'],
      phoneNumber: json['phone_number'],
      profilePictureUrl: json['profile_picture'] != null 
          ? 'http://127.0.0.1:8000${json['profile_picture']}'
          : null,
      role: json['role'] ?? 'citizen',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'phone_number': phoneNumber,
      'profile_picture': profilePictureUrl,
      'role': role,
    };
  }
}

