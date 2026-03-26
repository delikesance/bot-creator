import 'package:bot_creator/types/component.dart';
import 'package:bot_creator/widgets/component_v2_builder/component_node_factory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ComponentNodeFactory.create', () {
    test('creates ActionRowNode for actionRow type', () {
      final node = ComponentNodeFactory.create(ComponentV2Type.actionRow);
      expect(node, isA<ActionRowNode>());
      expect(node.type, ComponentV2Type.actionRow);
    });

    test('creates ButtonNode for button type', () {
      final node = ComponentNodeFactory.create(ComponentV2Type.button);
      expect(node, isA<ButtonNode>());
      expect(node.type, ComponentV2Type.button);
    });

    test('creates StringSelect with one default option', () {
      final node = ComponentNodeFactory.create(ComponentV2Type.stringSelect);
      expect(node, isA<SelectMenuNode>());
      final selectNode = node as SelectMenuNode;
      expect(selectNode.type, ComponentV2Type.stringSelect);
      expect(selectNode.options, isNotEmpty);
    });

    test('creates SelectMenuNode for userSelect type', () {
      final node = ComponentNodeFactory.create(ComponentV2Type.userSelect);
      expect(node, isA<SelectMenuNode>());
      expect(node.type, ComponentV2Type.userSelect);
    });

    test('creates SelectMenuNode for roleSelect type', () {
      final node = ComponentNodeFactory.create(ComponentV2Type.roleSelect);
      expect(node, isA<SelectMenuNode>());
      expect(node.type, ComponentV2Type.roleSelect);
    });

    test('creates SelectMenuNode for mentionableSelect type', () {
      final node = ComponentNodeFactory.create(
        ComponentV2Type.mentionableSelect,
      );
      expect(node, isA<SelectMenuNode>());
      expect(node.type, ComponentV2Type.mentionableSelect);
    });

    test('creates SelectMenuNode for channelSelect type', () {
      final node = ComponentNodeFactory.create(ComponentV2Type.channelSelect);
      expect(node, isA<SelectMenuNode>());
      expect(node.type, ComponentV2Type.channelSelect);
    });

    test('creates SectionNode with one TextDisplayNode child', () {
      final node = ComponentNodeFactory.create(ComponentV2Type.section);
      expect(node, isA<SectionNode>());
      final sectionNode = node as SectionNode;
      expect(sectionNode.components, hasLength(1));
      expect(sectionNode.components.first, isA<TextDisplayNode>());
    });

    test('creates TextDisplayNode for textDisplay type', () {
      final node = ComponentNodeFactory.create(ComponentV2Type.textDisplay);
      expect(node, isA<TextDisplayNode>());
      expect(node.type, ComponentV2Type.textDisplay);
    });

    test('creates ThumbnailNode for thumbnail type', () {
      final node = ComponentNodeFactory.create(ComponentV2Type.thumbnail);
      expect(node, isA<ThumbnailNode>());
      expect(node.type, ComponentV2Type.thumbnail);
    });

    test('creates MediaGalleryNode with one item', () {
      final node = ComponentNodeFactory.create(ComponentV2Type.mediaGallery);
      expect(node, isA<MediaGalleryNode>());
      final galleryNode = node as MediaGalleryNode;
      expect(galleryNode.items, hasLength(1));
    });

    test('creates FileNode for file type', () {
      final node = ComponentNodeFactory.create(ComponentV2Type.file);
      expect(node, isA<FileNode>());
      expect(node.type, ComponentV2Type.file);
    });

    test('creates SeparatorNode for separator type', () {
      final node = ComponentNodeFactory.create(ComponentV2Type.separator);
      expect(node, isA<SeparatorNode>());
      expect(node.type, ComponentV2Type.separator);
    });

    test('creates ContainerNode with one TextDisplayNode child', () {
      final node = ComponentNodeFactory.create(ComponentV2Type.container);
      expect(node, isA<ContainerNode>());
      final containerNode = node as ContainerNode;
      expect(containerNode.components, hasLength(1));
      expect(containerNode.components.first, isA<TextDisplayNode>());
    });

    test('creates LabelNode for label type', () {
      final node = ComponentNodeFactory.create(ComponentV2Type.label);
      expect(node, isA<LabelNode>());
      expect(node.type, ComponentV2Type.label);
    });

    test('creates FileUploadNode for fileUpload type', () {
      final node = ComponentNodeFactory.create(ComponentV2Type.fileUpload);
      expect(node, isA<FileUploadNode>());
      expect(node.type, ComponentV2Type.fileUpload);
    });

    test('creates RadioGroupNode with one default option', () {
      final node = ComponentNodeFactory.create(ComponentV2Type.radioGroup);
      expect(node, isA<RadioGroupNode>());
      final radioNode = node as RadioGroupNode;
      expect(radioNode.options, hasLength(1));
      expect(radioNode.options.first.value, 'a');
    });

    test('creates CheckboxGroupNode with one default option', () {
      final node = ComponentNodeFactory.create(ComponentV2Type.checkboxGroup);
      expect(node, isA<CheckboxGroupNode>());
      final cbGroupNode = node as CheckboxGroupNode;
      expect(cbGroupNode.options, hasLength(1));
      expect(cbGroupNode.options.first.value, 'a');
    });

    test('creates CheckboxNode for checkbox type', () {
      final node = ComponentNodeFactory.create(ComponentV2Type.checkbox);
      expect(node, isA<CheckboxNode>());
      expect(node.type, ComponentV2Type.checkbox);
    });

    test('covers all ComponentV2Type enum values', () {
      // Ensures the factory handles every type without throwing.
      for (final type in ComponentV2Type.values) {
        expect(
          () => ComponentNodeFactory.create(type),
          returnsNormally,
          reason: 'Factory should handle $type without throwing',
        );
      }
    });
  });

  group('ComponentNodeFactory.labelFor', () {
    test('capitalises the first letter', () {
      final label = ComponentNodeFactory.labelFor(ComponentV2Type.button);
      expect(label[0], equals('B'));
    });

    test('inserts spaces before uppercase letters in camelCase names', () {
      final label = ComponentNodeFactory.labelFor(ComponentV2Type.actionRow);
      expect(label, equals('Action Row'));
    });

    test('returns correct label for stringSelect', () {
      final label = ComponentNodeFactory.labelFor(ComponentV2Type.stringSelect);
      expect(label, equals('String Select'));
    });

    test('returns correct label for textDisplay', () {
      final label = ComponentNodeFactory.labelFor(ComponentV2Type.textDisplay);
      expect(label, equals('Text Display'));
    });

    test('returns correct label for mediaGallery', () {
      final label = ComponentNodeFactory.labelFor(ComponentV2Type.mediaGallery);
      expect(label, equals('Media Gallery'));
    });
  });

  group('ComponentNodeFactory – node JSON round-trip', () {
    test('created nodes serialise and deserialise without loss', () {
      for (final type in ComponentV2Type.values) {
        final node = ComponentNodeFactory.create(type);
        final json = node.toJson();
        final restored = ComponentNode.fromJson(json);
        expect(restored.type, equals(node.type));
      }
    });
  });
}
