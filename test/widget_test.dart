import 'package:flutter_test/flutter_test.dart';
import 'package:mylist/models.dart';

void main() {
  test('item json round-trips and labels are per-section', () {
    final it = Item(id: '1', title: 'Dune', cat: Cat.books, status: Status.ongoing, progress: 3, rating: 4, fav: true, added: 1);
    final back = Item.fromJson(it.toJson());
    expect(back.title, 'Dune');
    expect(back.cat, Cat.books);
    expect(back.status, Status.ongoing);
    expect(back.progress, 3);
    expect(back.fav, true);
    expect(Cat.books.statusLabel(Status.done), 'Read');
    expect(Cat.sites.statusLabel(Status.dropped), 'Dead');
  });
}
