/// 贴纸分类(面板分组用,顺序即分组展示顺序)。
enum StickerCategory { smileys, gestures, hearts, celebration }

/// 单个内置贴纸。id 同时是资产文件名(不含扩展名)。
class StickerItem {
  const StickerItem(this.id, this.category);

  final String id;
  final StickerCategory category;
}

