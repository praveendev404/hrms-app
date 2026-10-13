/// Model for dropdown options from GetParentOptions API
class DropdownOptionModel {
  final int value;
  final String label;
  final String? label2;
  final String? schema;
  final String? colorCode;
  final int? parentId;
  final String? parentName;
  final bool isNonEditable;

  DropdownOptionModel({
    required this.value,
    required this.label,
    this.label2,
    this.schema,
    this.colorCode,
    this.parentId,
    this.parentName,
    required this.isNonEditable,
  });

  factory DropdownOptionModel.fromJson(Map<String, dynamic> json) {
    return DropdownOptionModel(
      value: json['value'] ?? 0,
      label: json['label'] ?? '',
      label2: json['label2'],
      schema: json['schema'],
      colorCode: json['colorCode'],
      parentId: json['parentId'],
      parentName: json['parentName'],
      isNonEditable: json['isNonEditable'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'label': label,
      'label2': label2,
      'schema': schema,
      'colorCode': colorCode,
      'parentId': parentId,
      'parentName': parentName,
      'isNonEditable': isNonEditable,
    };
  }
}
