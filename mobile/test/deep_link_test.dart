import 'package:family_tree_mobile/deep_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeepLink.parse', () {
    test('parses /person/<id> path links', () {
      final link = DeepLink.parse(Uri.parse('https://omaritree.com/person/4356'));
      expect(link, isA<PersonLink>());
      expect((link! as PersonLink).id, 4356);
    });

    test('parses /path/<from>/<to> path links', () {
      final link = DeepLink.parse(Uri.parse('https://omaritree.com/path/12/4356'));
      expect(link, isA<PathLink>());
      final path = link! as PathLink;
      expect(path.from, 12);
      expect(path.to, 4356);
    });

    test('parses ?person= query links (web address bar)', () {
      final link = DeepLink.parse(Uri.parse('https://omaritree.com/?person=99'));
      expect((link! as PersonLink).id, 99);
    });

    test('parses ?from=&to= query links', () {
      final link =
          DeepLink.parse(Uri.parse('https://omaritree.com/?from=1&to=2'));
      final path = link! as PathLink;
      expect(path.from, 1);
      expect(path.to, 2);
    });

    test('ignores unrelated, malformed, or non-positive links', () {
      expect(DeepLink.parse(Uri.parse('https://omaritree.com/')), isNull);
      expect(DeepLink.parse(Uri.parse('https://omaritree.com/about')), isNull);
      expect(DeepLink.parse(Uri.parse('https://omaritree.com/person/abc')),
          isNull);
      expect(
          DeepLink.parse(Uri.parse('https://omaritree.com/person/0')), isNull);
      expect(DeepLink.parse(Uri.parse('https://omaritree.com/path/1')), isNull);
    });
  });

  group('share URLs', () {
    test('build round-trips back to the same link', () {
      final personUri = personShareUri(4356);
      expect(DeepLink.parse(personUri), isA<PersonLink>());

      final pathUri = pathShareUri(12, 4356);
      final parsed = DeepLink.parse(pathUri)! as PathLink;
      expect(parsed.from, 12);
      expect(parsed.to, 4356);
    });
  });
}
