import 'dart:typed_data';

/// 从 TTF/OTF/TTC 字体文件字节中解析 family 名称（OpenType name table，
/// nameID = 1 的 Family Name 记录）。
///
/// 纯 Dart 实现，零依赖，可用于导入字体时获取真实字体名。
/// TTC 集合取第一个字体的名称。返回 `null` 表示无法解析。
String? parseFontFamilyName(Uint8List bytes) {
  try {
    if (bytes.length < 12) return null;
    final bd = ByteData.sublistView(bytes);

    // ── sfnt header（支持 TTC 集合，取第一个字体）──
    final magic = bd.getUint32(0);
    // 0x00010000 = TrueType；'OTTO' = CFF/OpenType
    var sfntOffset = 0;
    if (magic == 0x74746366) {
      // 'ttcf'：numFonts @ 8，字体 offset 数组从 12 开始
      final numFonts = bd.getUint32(8);
      if (numFonts == 0) return null;
      sfntOffset = bd.getUint32(12);
    } else if (magic != 0x00010000 && magic != 0x4F54544F) {
      return null;
    }
    if (sfntOffset + 12 > bytes.length) return null;

    final numTables = bd.getUint16(sfntOffset + 4);

    // ── table records（每条 16 字节，从 sfntOffset + 12 开始）──
    int? nameOffset;
    int? nameLength;
    for (var i = 0; i < numTables; i++) {
      final rec = sfntOffset + 12 + i * 16;
      if (rec + 16 > bytes.length) return null;
      final tag = String.fromCharCodes(
        [bd.getUint8(rec), bd.getUint8(rec + 1), bd.getUint8(rec + 2), bd.getUint8(rec + 3)],
      );
      if (tag == 'name') {
        nameOffset = bd.getUint32(rec + 8);
        nameLength = bd.getUint32(rec + 12);
        break;
      }
    }
    if (nameOffset == null || nameOffset + nameLength! > bytes.length) {
      return null;
    }

    // ── name table ──
    // header: format(u16) count(u16) stringOffset(u16)
    final count = bd.getUint16(nameOffset + 2);
    final stringBase = nameOffset + bd.getUint16(nameOffset + 4);

    String? best;
    var bestPriority = 99; // 越小越优先
    for (var i = 0; i < count; i++) {
      final rec = nameOffset + 6 + i * 12;
      if (rec + 12 > nameOffset + nameLength) break;
      final platformID = bd.getUint16(rec);
      final nameID = bd.getUint16(rec + 6);
      if (nameID != 1) continue; // 1 = Family Name
      final length = bd.getUint16(rec + 8);
      final offset = stringBase + bd.getUint16(rec + 10);
      if (offset + length > bytes.length) continue;

      // 优先级：Windows（UTF-16BE）> Unicode（UTF-16BE）> Mac（Mac Roman）
      final priority = switch (platformID) {
        3 => 0,
        0 => 1,
        _ => 2,
      };
      if (priority >= bestPriority) continue;

      final String value;
      if (platformID == 1) {
        value = _decodeMacRoman(bytes, offset, length);
      } else {
        value = _decodeUtf16Be(bytes, offset, length);
      }
      if (value.isEmpty || value.contains('\u0000')) continue;
      best = value;
      bestPriority = priority;
    }
    return best;
  } catch (_) {
    return null;
  }
}

String _decodeUtf16Be(Uint8List bytes, int offset, int length) {
  final codeUnits = List<int>.generate(length ~/ 2, (i) {
    return (bytes[offset + i * 2] << 8) | bytes[offset + i * 2 + 1];
  });
  return String.fromCharCodes(codeUnits);
}

/// Mac Roman 编码（仅覆盖常见范围，无法识别时返回空串）。
String _decodeMacRoman(Uint8List bytes, int offset, int length) {
  const extra = <int, String>{
    0x80: 'Ä',
    0x81: 'Å',
    0x82: 'Ç',
    0x83: 'É',
    0x84: 'Ñ',
    0x85: 'Ö',
    0x86: 'Ü',
    0x87: 'á',
    0x88: 'à',
    0x89: 'â',
    0x8A: 'ä',
    0x8B: 'ã',
    0x8C: 'å',
    0x8D: 'ç',
    0x8E: 'é',
    0x8F: 'è',
    0x90: 'ê',
    0x91: 'ë',
    0x92: 'í',
    0x93: 'ì',
    0x94: 'î',
    0x95: 'ï',
    0x96: 'ñ',
    0x97: 'ó',
    0x98: 'ò',
    0x99: 'ô',
    0x9A: 'ö',
    0x9B: 'õ',
    0x9C: 'ú',
    0x9D: 'ù',
    0x9E: 'û',
    0x9F: 'ü',
  };
  final sb = StringBuffer();
  for (var i = 0; i < length; i++) {
    final b = bytes[offset + i];
    if (b < 0x80) {
      sb.writeCharCode(b);
    } else {
      sb.write(extra[b] ?? '');
    }
  }
  return sb.toString();
}
