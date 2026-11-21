import 'dart:typed_data';

class GpsRecord {
  const GpsRecord({
    required this.time,
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
  });

  final DateTime time; // UTC
  final double latitude;
  final double longitude;
  final double speedKmh;

  static const int size = 16;

  // CRC-16, polynomial 0x1021, start value 0xFFFF: the same as record.c on the board
  static int crc16(List<int> data) {
    var crc = 0xFFFF;
    for (final b in data) {
      crc ^= (b & 0xFF) << 8;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 0x8000) != 0
            ? ((crc << 1) ^ 0x1021) & 0xFFFF
            : (crc << 1) & 0xFFFF;
      }
    }
    return crc;
  }

  /// Returns null when the packet has the wrong length or a bad CRC.
  static GpsRecord? decode(List<int> bytes) {
    if (bytes.length != size) return null;
    final bd = ByteData.sublistView(Uint8List.fromList(bytes));
    if (bd.getUint16(14, Endian.little) != crc16(bytes.sublist(0, 14))) {
      return null;
    }
    return GpsRecord(
      time: DateTime.fromMillisecondsSinceEpoch(
          bd.getUint32(0, Endian.little) * 1000,
          isUtc: true),
      latitude: bd.getInt32(4, Endian.little) / 1e6,
      longitude: bd.getInt32(8, Endian.little) / 1e6,
      speedKmh: bd.getUint16(12, Endian.little) / 10.0,
    );
  }

  /// The distance characteristic: 4 bytes, meters, low byte first.
  static int? decodeDistanceMeters(List<int> bytes) {
    if (bytes.length != 4) return null;
    return ByteData.sublistView(Uint8List.fromList(bytes))
        .getUint32(0, Endian.little);
  }
}