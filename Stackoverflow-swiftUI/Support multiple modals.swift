https://stackoverflow.com/questions/57103800/swiftui-support-multiple-modals/57105822#57105822

Multiple .sheet() approach:

import SwiftUI

struct MultipleSheets: View {
    @State private var sheet1 = false
    @State private var sheet2 = false
    @State private var sheet3 = false

    var body: some View {
        VStack {

            Button(action: {
                self.sheet1 = true
            }, label: { Text("Show Modal #1") })
            .sheet(isPresented: $sheet1, content: { Sheet1() })

            Button(action: {
                self.sheet2 = true
            }, label: { Text("Show Modal #2") })
            .sheet(isPresented: $sheet2, content: { Sheet2() })

            Button(action: {
                self.sheet3 = true
            }, label: { Text("Show Modal #3") })
            .sheet(isPresented: $sheet3, content: { Sheet3() })

        }
    }
}

struct Sheet1: View {
    var body: some View {
        Text("This is Sheet #1")
    }
}

struct Sheet2: View {
    var body: some View {
        Text("This is Sheet #2")
    }
}

struct Sheet3: View {
    var body: some View {
        Text("This is Sheet #3")
    }
}

Maybe I missed the point, but you can achieve it either with a single call to .sheet(), or multiple calls.:

Multiple .sheet() approach:

import SwiftUI

struct MultipleSheets: View {
    @State private var sheet1 = false
    @State private var sheet2 = false
    @State private var sheet3 = false

    var body: some View {
        VStack {

            Button(action: {
                self.sheet1 = true
            }, label: { Text("Show Modal #1") })
            .sheet(isPresented: $sheet1, content: { Sheet1() })

            Button(action: {
                self.sheet2 = true
            }, label: { Text("Show Modal #2") })
            .sheet(isPresented: $sheet2, content: { Sheet2() })

            Button(action: {
                self.sheet3 = true
            }, label: { Text("Show Modal #3") })
            .sheet(isPresented: $sheet3, content: { Sheet3() })

        }
    }
}

struct Sheet1: View {
    var body: some View {
        Text("This is Sheet #1")
    }
}

struct Sheet2: View {
    var body: some View {
        Text("This is Sheet #2")
    }
}

struct Sheet3: View {
    var body: some View {
        Text("This is Sheet #3")
    }
}


Single .sheet() approach:

struct MultipleSheets: View {
    @State private var showModal = false
    @State private var modalSelection = 1

    var body: some View {
        VStack {

            Button(action: {
                self.modalSelection = 1
                self.showModal = true
            }, label: { Text("Show Modal #1") })

            Button(action: {
                self.modalSelection = 2
                self.showModal = true
            }, label: { Text("Show Modal #2") })

            Button(action: {
                self.modalSelection = 3
                self.showModal = true
            }, label: { Text("Show Modal #3") })

        }
        .sheet(isPresented: $showModal, content: {
            if self.modalSelection == 1 {
                Sheet1()
            }

            if self.modalSelection == 2 {
                Sheet2()
            }

            if self.modalSelection == 3 {
                Sheet3()
            }
        })

    }
}

struct Sheet1: View {
    var body: some View {
        Text("This is Sheet #1")
    }
}

struct Sheet2: View {
    var body: some View {
        Text("This is Sheet #2")
    }
}

struct Sheet3: View {
    var body: some View {
        Text("This is Sheet #3")
    }
}
