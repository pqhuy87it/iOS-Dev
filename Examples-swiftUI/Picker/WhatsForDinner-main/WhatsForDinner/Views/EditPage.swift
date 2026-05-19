//
//  EditPage.swift
//  WhatsForDinner
//
//  Created by Matt Burke on 1/17/21.
//

import SwiftUI

fileprivate func noop<T>(param: T) -> Void { }

struct EditPage: View {
    let original: Restaurant?
    let complete: (Restaurant) -> Void
    @State private var draft: Restaurant = Restaurant.empty

    init(original: Restaurant? = nil, complete: @escaping (Restaurant) -> Void) {
        self.original = original
        self.complete = complete
    }

    func createDraft() {
        if original == nil {
            draft = Restaurant.empty
        } else {
            draft = original!
        }
    }

    func update() {
        complete(draft)
    }

    var body: some View {
        EditForm(draft: $draft)
            .onAppear(perform: createDraft)
            .onDisappear(perform: update)
    }
}

struct EditForm: View {

    @Binding var draft: Restaurant

    var body: some View {
        Form {
            TextField("Name", text: $draft.name)
        }
    }
}

struct EditPage_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            EditPage(original: Restaurant.samples[0], complete: noop)
            EditPage(complete: noop)
        }
    }
}
