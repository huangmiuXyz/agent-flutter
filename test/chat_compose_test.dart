import 'package:fleather/fleather.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent/features/chat/chat_fleather.dart';

void main() {
  group('图片标签（Fleather embed）', () {
    test('insertImageTag 在光标处插入并按序编号（携带原始名）', () {
      final controller = FleatherController();
      expect(countImageTags(controller), 0);

      insertImageTag(
        controller,
        '/data/File/img_aaa.png',
        'img_aaa.png',
        displayName: 'photo.png',
      );
      insertImageTag(
        controller,
        '/data/File/img_bbb.png',
        'img_bbb.png',
        displayName: 'photo.png',
      );

      expect(countImageTags(controller), 2);

      final delta = controller.document.toDelta();
      final embeds = delta.toList().where((op) {
        final data = op.data;
        return data is Map && data[EmbeddableObject.kTypeKey] == kImageEmbedType;
      }).toList();
      expect(embeds.length, 2);
      expect((embeds[0].data as Map)['label'], '图片1');
      expect((embeds[1].data as Map)['label'], '图片2');
      expect((embeds[0].data as Map)['path'], '/data/File/img_aaa.png');
      expect((embeds[0].data as Map)['displayName'], 'photo.png');
    });

    test('extractChatCompose 提取文本（标签转 [图片N]）与按序图片路径', () {
      final controller = FleatherController();
      controller.compose(
        Delta()
          ..retain(0)
          ..insert('帮我参考')
          ..insert({
            EmbeddableObject.kTypeKey: kImageEmbedType,
            EmbeddableObject.kInlineKey: true,
            'path': '/data/File/img_aaa.png',
            'filename': 'img_aaa.png',
            'label': '图片1',
            'displayName': 'photo.png',
          })
          ..insert('实现任务\n'),
        source: ChangeSource.local,
      );

      final compose = extractChatCompose(controller);
      // 初始文档自带一个 \n，共两个；标签转回 [图片N] 编号
      expect(compose.text, '帮我参考[图片1]实现任务\n\n');
      expect(compose.imagePaths, ['/data/File/img_aaa.png']);
      expect(compose.imageNames, ['photo.png']);
    });

    test('extractChatCompose 多图片保持文档顺序，同名原始名不影响编号', () {
      final controller = FleatherController();
      controller.compose(
        Delta()
          ..retain(0)
          ..insert({
            EmbeddableObject.kTypeKey: kImageEmbedType,
            EmbeddableObject.kInlineKey: true,
            'path': '/data/File/img_1.png',
            'filename': 'img_1.png',
            'label': '图片1',
            'displayName': 'photo.png',
          })
          ..insert('和')
          ..insert({
            EmbeddableObject.kTypeKey: kImageEmbedType,
            EmbeddableObject.kInlineKey: true,
            'path': '/data/File/img_2.png',
            'filename': 'img_2.png',
            'label': '图片2',
            'displayName': 'photo.png',
          })
          ..insert('\n'),
        source: ChangeSource.local,
      );

      final compose = extractChatCompose(controller);
      // 初始文档自带一个 \n，共两个；同名原始名不产生歧义（编号引用）
      expect(compose.text, '[图片1]和[图片2]\n\n');
      expect(compose.imagePaths, [
        '/data/File/img_1.png',
        '/data/File/img_2.png',
      ]);
      expect(compose.imageNames, ['photo.png', 'photo.png']);
    });

    group('buildUserMessageDelta（历史消息 → 编辑文档）', () {
      test('文本中的 [图片N] 标记替换为对应位置的标签', () {
        final delta = buildUserMessageDelta(
          text: '帮我参考[图片1]实现任务',
          imagePaths: ['/data/File/a.png', '/data/File/b.png'],
          storedNames: ['a.png', 'b.png'],
          displayNames: ['photoA.png', 'photoB.png'],
        );

        final controller = FleatherController();
        controller.compose(delta, source: ChangeSource.local);

        // 提交时标签转回 [图片N]；图片2 未被引用 → 追加在末尾
        final compose = extractChatCompose(controller);
        expect(compose.text, '帮我参考[图片1]实现任务[图片2]\n\n');
        expect(compose.imagePaths, ['/data/File/a.png', '/data/File/b.png']);
        expect(compose.imageNames, ['photoA.png', 'photoB.png']);
      });

      test('文本中恰好出现的文件名不参与匹配（避免误替换）', () {
        final delta = buildUserMessageDelta(
          text: '帮我看看 a.png 这个文件',
          imagePaths: ['/data/File/img_x.png'],
          storedNames: ['img_x.png'],
          displayNames: ['a.png'],
        );

        final controller = FleatherController();
        controller.compose(delta, source: ChangeSource.local);

        final compose = extractChatCompose(controller);
        // 文本中的 a.png 保持原样，图片作为未引用附件追加在末尾
        expect(compose.text, '帮我看看 a.png 这个文件[图片1]\n\n');
        expect(compose.imagePaths, ['/data/File/img_x.png']);
      });

      test('未被文本引用的图片追加在末尾', () {
        final delta = buildUserMessageDelta(
          text: '看图',
          imagePaths: ['/data/File/a.png', '/data/File/b.png'],
          storedNames: ['a.png', 'b.png'],
          displayNames: ['photoA.png', 'photoB.png'],
        );

        final controller = FleatherController();
        controller.compose(delta, source: ChangeSource.local);

        final compose = extractChatCompose(controller);
        expect(compose.text, '看图[图片1][图片2]\n\n');
        expect(compose.imagePaths, ['/data/File/a.png', '/data/File/b.png']);
      });

      test('引用编号超出图片数量时保留原文本', () {
        final delta = buildUserMessageDelta(
          text: '[图片3]异常引用',
          imagePaths: ['/data/File/a.png'],
          storedNames: ['a.png'],
          displayNames: ['photoA.png'],
        );

        final controller = FleatherController();
        controller.compose(delta, source: ChangeSource.local);

        final compose = extractChatCompose(controller);
        expect(compose.text, '[图片3]异常引用[图片1]\n\n');
        expect(compose.imagePaths, ['/data/File/a.png']);
      });
    });
  });
}
