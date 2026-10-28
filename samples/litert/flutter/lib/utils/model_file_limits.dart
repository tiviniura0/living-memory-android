/// Same bound as the Android SAF importer; shared by download, local adoption
/// and private registration. Refuse before parsing weights or creating copies.
const kMaximumModelBytes = 8 * 1024 * 1024 * 1024;

void validateModelSize(int bytes) {
  if (bytes <= 0 || bytes > kMaximumModelBytes) {
    throw const FormatException('Modèle : taille de 1 octet à 8 Gio requise.');
  }
}
