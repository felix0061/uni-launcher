/// A field is usable only while its own read is valid and fresh.
class VehicleField {
  final Object? value;
  final String unit, source;
  final bool valid;
  const VehicleField(
      {this.value, this.unit = '', this.source = '', this.valid = false});
  factory VehicleField.fromNative(Map<String, dynamic> native, String key,
      {int? nowMs}) {
    final vehicle =
        native['vehicle'] is Map ? native['vehicle'] as Map : const {};
    final fields =
        vehicle['fields'] is Map ? vehicle['fields'] as Map : const {};
    final field = fields[key] is Map ? fields[key] as Map : const {};
    final timestamp = (field['updatedAtMs'] as num?)?.toInt() ?? 0;
    final age = (nowMs ?? DateTime.now().millisecondsSinceEpoch) - timestamp;
    final valid = vehicle['connected'] == true &&
        field['valid'] == true &&
        timestamp > 0 &&
        age >= -1000 &&
        age <= 5000;
    return VehicleField(
        value: valid ? field['value'] : null,
        unit: '${field['unit'] ?? ''}',
        source: '${field['source'] ?? ''}',
        valid: valid);
  }
  String display({int decimals = 1}) => !valid
      ? '—'
      : value is num
          ? (value as num).toStringAsFixed(decimals)
          : value == true
              ? '开启'
              : value == false
                  ? '关闭'
                  : '$value';
}
