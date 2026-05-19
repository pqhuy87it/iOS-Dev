https://stackoverflow.com/questions/57270850/send-and-sink-do-not-seem-to-work-anymore-for-passthroughsubject-in-xcode/57272955#57272955

.sink() returns an AnyCancellable object. You should never ignored it. Never do this:

// never do this!
publisher.sink { ... }
// never do this!
let _ = publisher.sink { ... }
And if you assign it to a variable, make sure it is not short lived. As soon as the cancellable object gets deallocated, the subscription will get cancelled too.

// if cancellable is deallocated, the subscription will get cancelled
let cancellable = publisher.sink { ... }
Since you asked to use sink inside a view, I'll post a way of doing it. However, inside a view, you should probably use .onReceive() instead. It is way more simple.

Using sink:

When using it inside a view, you need to use a @State variable, to make sure it survives after the view body was generated.

The DispatchQueue.main.async is required, to avoid the state being modified while the view updates. You would get a runtime error if you didn't.

struct ContentView: View {
    @State var cancellable: AnyCancellable? = nil

    var body: some View {
        let publisher = PassthroughSubject<String, Never>()

        DispatchQueue.main.async {
            self.cancellable = publisher.sink { (str) in
                print(str)
            }
        }

        return Button("OK") {
            publisher.send("Test")
        }
    }
}
Using .onReceive()

struct ContentView: View {

    var body: some View {
        let publisher = PassthroughSubject<String, Never>()

        return Button("OK") {
            publisher.send("Test")
        }
        .onReceive(publisher) { str in
            print(str)
        }
    }
}
