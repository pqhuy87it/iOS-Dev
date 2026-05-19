import SwiftUI

class MyModel: ObservableObject {
    @Published var attempted: Bool = false
    
    @Published var firstname: String = "" {
        didSet { updateDismissability() }
    }
    
    @Published var lastname: String = "" {
        didSet { updateDismissability() }
    }
    
    @Published var preventDismissal: Bool = false
    
    func updateDismissability() {
        self.preventDismissal = lastname != "" || firstname != ""
    }
    
    func save() {
        print("save data")
        self.resetForm()
    }
    
    func resetForm() {
        self.firstname = ""
        self.lastname = ""
    }
}

struct ContentView: View {
    var body: some View {
        MyView()
    }
}

struct MyView: View {
    @State private var modal1 = false
    @State private var modal2 = false
    @ObservedObject var model = MyModel()
    
    var body: some View {
        DismissGuardian(preventDismissal: $model.preventDismissal, attempted: $model.attempted) {
            VStack {
                Text("Dismiss Guardian").font(.title)

                Button("Modal Without Feedback") {
                    self.modal1 = true
                }.padding(20)
                .sheet(isPresented: self.$modal1, content: { MyModal().environmentObject(self.model) })

                Button("Modal With Feedback") {
                    self.modal2 = true
                }
                .sheet(isPresented: self.$modal2, content: { MyModalWithFeedback().environmentObject(self.model) })
            }
        }
    }
}

struct MyModal: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var model: MyModel

    var body: some View {
        NavigationView {
            Form {
                TextField("First name", text: $model.firstname)
                TextField("Last name", text: $model.lastname)
            }
            .navigationBarTitle("Form (without feedback)", displayMode: .inline)
            .navigationBarItems(trailing:
                Button("Save") {
                    self.model.save()
                    self.presentationMode.wrappedValue.dismiss() }
            )
        }
        .environment(\.horizontalSizeClass, .compact)
    }
}

struct MyModalWithFeedback: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var model: MyModel

    var body: some View {
        NavigationView {
            Form {
                TextField("First name", text: $model.firstname)
                TextField("Last name", text: $model.lastname)
            }
            .alert(isPresented: self.$model.attempted) {
                Alert(title: Text("Unsaved Changes"),
                      message: Text("You have made changes to the form that have not been saved. If you continue, those changes will be lost."),
                      primaryButton: .destructive(Text("Delete Changes"), action: {
                        self.model.resetForm()
                        self.presentationMode.wrappedValue.dismiss()
                      }),
                      secondaryButton: .cancel(Text("Continue Editing")))
            }
            .navigationBarTitle("Form (with feedback)", displayMode: .inline)
            .navigationBarItems(trailing:
                Button("Save") {
                    self.model.save()
                    self.presentationMode.wrappedValue.dismiss() }
            )
        }
        .environment(\.horizontalSizeClass, .compact)
    }
}

struct DismissGuardian<Content: View>: UIViewControllerRepresentable {
    @Binding var preventDismissal: Bool
    @Binding var attempted: Bool
    var contentView: Content
    
    init(preventDismissal: Binding<Bool>, attempted: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) {
        self.contentView = content()
        self._preventDismissal = preventDismissal
        self._attempted = attempted
    }
        
    func makeUIViewController(context: UIViewControllerRepresentableContext<DismissGuardian>) -> UIViewController {
        return DismissGuardianUIHostingController(rootView: contentView, preventDismissal: preventDismissal)
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: UIViewControllerRepresentableContext<DismissGuardian>) {
        (uiViewController as! DismissGuardianUIHostingController).rootView = contentView
        (uiViewController as! DismissGuardianUIHostingController<Content>).preventDismissal = preventDismissal
        (uiViewController as! DismissGuardianUIHostingController<Content>).dismissGuardianDelegate = context.coordinator
    }
    
    func makeCoordinator() -> DismissGuardian<Content>.Coordinator {
        return Coordinator(attempted: $attempted)
    }
    
    class Coordinator: NSObject, DismissGuardianDelegate {
        @Binding var attempted: Bool
        
        init(attempted: Binding<Bool>) {
            self._attempted = attempted
        }
        
        func attemptedUpdate(flag: Bool) {
            self.attempted = flag
        }
    }
}

protocol DismissGuardianDelegate {
    func attemptedUpdate(flag: Bool)
}

class DismissGuardianUIHostingController<Content> : UIHostingController<Content>, UIAdaptivePresentationControllerDelegate where Content : View {
    var preventDismissal: Bool
    var dismissGuardianDelegate: DismissGuardianDelegate?

    init(rootView: Content, preventDismissal: Bool) {
        self.preventDismissal = preventDismissal
        super.init(rootView: rootView)
    }
    
    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        viewControllerToPresent.presentationController?.delegate = self
        
        self.dismissGuardianDelegate?.attemptedUpdate(flag: false)
        super.present(viewControllerToPresent, animated: flag, completion: completion)
    }
    
    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        self.dismissGuardianDelegate?.attemptedUpdate(flag: true)
    }
    
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        return !self.preventDismissal
    }
}
