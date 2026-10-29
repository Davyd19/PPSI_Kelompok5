class DemoProfile {
  const DemoProfile({
    required this.id,
    required this.role,
    required this.roleLabel,
    required this.name,
    required this.platform,
  });
  final String id, role, roleLabel, name, platform;
  factory DemoProfile.fromJson(Map<String, dynamic> json) => DemoProfile(
    id: json['id'] as String,
    role: json['role'] as String,
    roleLabel: json['roleLabel'] as String,
    name: json['name'] as String,
    platform: json['platform'] as String,
  );
}
