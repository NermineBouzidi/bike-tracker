class AppUser {
  const AppUser({required this.id, required this.email, required this.displayName});

  final int id;
  final String email;
  final String displayName;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: (json['id'] as num).toInt(),
        email: json['email'] as String,
        displayName: json['displayName'] as String,
      );
}