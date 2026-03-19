class AppEmoji {
  final String id;
  final String name;
  final bool animated;

  const AppEmoji({
    required this.id,
    required this.name,
    required this.animated,
  });

  factory AppEmoji.fromJson(Map<String, dynamic> json) {
    return AppEmoji(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      animated: json['animated'] == true,
    );
  }

  /// CDN URL for the emoji image (PNG or GIF).
  String get imageUrl {
    final ext = animated ? 'gif' : 'png';
    return 'https://cdn.discordapp.com/emojis/$id.$ext?size=64';
  }

  /// Discord mention string, e.g. `<:wave:123456>` or `<a:wave:123456>`.
  String get mention => animated ? '<a:$name:$id>' : '<:$name:$id>';
}
