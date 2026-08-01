import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/ssi/ssi_buddy_code.dart';
import 'package:ssi_connect/ssi/ssi_buddy_directory.dart';

SsiBuddyCode _member(String id, {String? first, String? last}) =>
    SsiBuddyCode(memberId: id, firstName: first, lastName: last);

void main() {
  group('ssiBuddyCandidates', () {
    test('merges account identities and saved buddies', () {
      final candidates = ssiBuddyCandidates(
        accountIdentities: [_member('1', first: 'Ada')],
        savedBuddies: [_member('2', first: 'Bo')],
      );

      expect(candidates.map((b) => b.memberId), ['1', '2']);
    });

    test('drops the diver themselves - nobody is their own buddy', () {
      final diver = _member('1', first: 'Ada');
      final candidates = ssiBuddyCandidates(
        accountIdentities: [
          diver,
          _member('2', first: 'Bo'),
        ],
        savedBuddies: [_member('3', first: 'Cy')],
        diver: diver,
      );

      expect(candidates.map((b) => b.memberId), ['2', '3']);
    });

    test('drops the diver even when they are only a saved buddy', () {
      final candidates = ssiBuddyCandidates(
        accountIdentities: const [],
        savedBuddies: [_member('7', first: 'Ada')],
        diver: _member('7'),
      );

      expect(candidates, isEmpty);
    });

    test('lists a member once when both sources know them', () {
      final candidates = ssiBuddyCandidates(
        accountIdentities: [_member('5', first: 'Ada', last: 'Lovelace')],
        savedBuddies: [_member('5', first: 'A.')],
      );

      expect(candidates, hasLength(1));
      // The account identity wins: it is the entry the user maintains, so a
      // name corrected there must not be shadowed by an older scan.
      expect(candidates.single.fullName, 'Ada Lovelace');
    });

    test('sorts by display name, case-insensitively', () {
      final candidates = ssiBuddyCandidates(
        accountIdentities: const [],
        savedBuddies: [
          _member('1', first: 'zoe'),
          _member('2', first: 'Ada'),
          _member('3', first: 'bo'),
        ],
      );

      expect(candidates.map((b) => b.firstName), ['Ada', 'bo', 'zoe']);
    });

    test('falls back to the member number for nameless entries', () {
      final candidates = ssiBuddyCandidates(
        accountIdentities: const [],
        savedBuddies: [_member('4711')],
      );

      expect(candidates.single.displayName, 'SSI-Nr. 4711');
    });
  });
}
