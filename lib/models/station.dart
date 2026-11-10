/// 不可变电台模型。界面、缓存和媒体服务共用，不依赖 Flutter Widget。
class Station {
  const Station({
    required this.id,
    required this.name,
    required this.region,
    required this.category,
    required this.urls,
    this.frequency = '--',
    this.homepage = '',
  });
  final String id, name, region, category, frequency, homepage;
  final List<String> urls;

  factory Station.fromJson(Map<String, dynamic> json) => Station(
    id: json['id'] as String,
    name: json['name'] as String,
    region: json['region'] as String,
    category: json['category'] as String,
    frequency: json['frequency'] as String? ?? '--',
    homepage: json['homepage'] as String? ?? '',
    urls: List<String>.unmodifiable((json['urls'] as List).cast<String>()),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'region': region,
    'category': category,
    'frequency': frequency,
    'homepage': homepage,
    'urls': urls,
  };

  bool matches(String query) => '$name $region $category $frequency'
      .toLowerCase()
      .contains(query.trim().toLowerCase());
}
