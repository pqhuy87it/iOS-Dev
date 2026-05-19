https://www.hackingwithswift.com/forums/swiftui/how-do-i-bind-toggle-to-an-item-in-an-array-with-foreach/410

import Foundation

struct IndexedCollection<Base: RandomAccessCollection>: RandomAccessCollection {
    typealias Index = Base.Index
    typealias Element = (index: Index, element: Base.Element)

    let base: Base

    var startIndex: Index { base.startIndex }

    var endIndex: Index { base.endIndex }

    func index(after i: Index) -> Index {
        base.index(after: i)
    }

    func index(before i: Index) -> Index {
        base.index(before: i)
    }

    func index(_ i: Index, offsetBy distance: Int) -> Index {
        base.index(i, offsetBy: distance)
    }

    subscript(position: Index) -> Element {
        (index: position, element: base[position])
    }
}

extension RandomAccessCollection {
    func indexed() -> IndexedCollection<Self> {
        IndexedCollection(base: self)
    }
}

import SwiftUI

struct BooksView: View {
    @ObservedObject var books: Books

    var body: some View {
        List {
            ForEach(books.items.indexed(), id: \.1.id) { index, book in
                Toggle(book.name, isOn: self.$books.items[index].enabled)
            }
        }
    }
}
