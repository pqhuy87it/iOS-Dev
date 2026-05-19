https://stackoverflow.com/questions/56973959/swiftui-how-to-implement-a-custom-init-with-binding-variables/56975728#56975728

Argh! You were so close. This is how you do it. You missed a dollar sign (beta 3) or underscore (beta 4), and either self in front of your amount property, or .value after the amount parameter. All these options work:

You'll see that I removed the @Statein includeDecimal, check the explanation at the end.

This is using the property (put self in front of it):

struct AmountView : View {
    @Binding var amount: Double

    private var includeDecimal = false

    init(amount: Binding<Double>) {

        // self.$amount = amount // beta 3
        self._amount = amount // beta 4

        self.includeDecimal = round(self.amount)-self.amount > 0
    }
}

or using .value after (but without self, because you are using the passed parameter, not the struct's property):

struct AmountView : View {
    @Binding var amount: Double

    private var includeDecimal = false

    init(amount: Binding<Double>) {
        // self.$amount = amount // beta 3
        self._amount = amount // beta 4

        self.includeDecimal = round(amount.value)-amount.value > 0
    }
}

his is the same, but we use different names for the parameter (withAmount) and the property (amount), so you clearly see when you are using each.

struct AmountView : View {
    @Binding var amount: Double

    private var includeDecimal = false

    init(withAmount: Binding<Double>) {
        // self.$amount = withAmount // beta 3
        self._amount = withAmount // beta 4

        self.includeDecimal = round(self.amount)-self.amount > 0
    }
}

struct AmountView : View {
    @Binding var amount: Double

    private var includeDecimal = false

    init(withAmount: Binding<Double>) {
        // self.$amount = withAmount // beta 3
        self._amount = withAmount // beta 4

        self.includeDecimal = round(withAmount.value)-withAmount.value > 0
    }
}

Note that .value is not necessary with the property, thanks to the property wrapper (@Binding), which creates the accessors that makes the .value unnecessary. However, with the parameter, there is not such thing and you have to do it explicitly. If you would like to learn more about property wrappers, check the WWDC session 415 - Modern Swift API Design and jump to 23:12.

As you discovered, modifying the @State variable from the initilizer will throw the following error: Thread 1: Fatal error: Accessing State outside View.body. To avoid it, you should either remove the @State. Which makes sense because includeDecimal is not a source of truth. Its value is derived from amount. By removing @State, however, includeDecimal will not update if amount changes. To achieve that, the best option, is to define your includeDecimal as a computed property, so that its value is derived from the source of truth (amount). This way, whenever the amount changes, your includeDecimal does too. If your view depends on includeDecimal, it should update when it changes:

struct AmountView : View {
    @Binding var amount: Double

    private var includeDecimal: Bool {
        return round(amount)-amount > 0
    }

    init(withAmount: Binding<Double>) {
        self.$amount = withAmount
    }

    var body: some View { ... }
}
As indicated by rob mayoff, you can also use $$varName (beta 3), or _varName (beta4) to initialise a State variable:

// Beta 3:
$$includeDecimal = State(initialValue: (round(amount.value) - amount.value) != 0)

// Beta 4:
_includeDecimal = State(initialValue: (round(amount.value) - amount.value) != 0)
