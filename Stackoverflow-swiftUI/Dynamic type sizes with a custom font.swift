https://stackoverflow.com/questions/56726869/is-it-possible-to-use-dynamic-type-sizes-with-a-custom-font-in-swiftui/56730649#56730649

Whenever you need to use Papyrus, you would use it like this:

Text("Hello World!").modifier(Papyrus())
or like this:

Text("Hello World!").modifier(Papyrus(.caption))
Text("Hello World!").modifier(Papyrus(.footnote))
Text("Hello World!").modifier(Papyrus(.subheadline))
Text("Hello World!").modifier(Papyrus(.callout))
Text("Hello World!").modifier(Papyrus())
Text("Hello World!").modifier(Papyrus(.body))
Text("Hello World!").modifier(Papyrus(.headline))
Text("Hello World!").modifier(Papyrus(.title))
Text("Hello World!").modifier(Papyrus(.largeTitle))

The way I would do it, is by creating a custom modifier that can be bound to the changes of the environment's size category:

Whenever you need to use Papyrus, you would use it like this:

Text("Hello World!").modifier(Papyrus())
or like this:

Text("Hello World!").modifier(Papyrus(.caption))
Text("Hello World!").modifier(Papyrus(.footnote))
Text("Hello World!").modifier(Papyrus(.subheadline))
Text("Hello World!").modifier(Papyrus(.callout))
Text("Hello World!").modifier(Papyrus())
Text("Hello World!").modifier(Papyrus(.body))
Text("Hello World!").modifier(Papyrus(.headline))
Text("Hello World!").modifier(Papyrus(.title))
Text("Hello World!").modifier(Papyrus(.largeTitle))
Your text will now dynamically change without further work. This is the same code, reacting to different text size preference:

enter image description here

And your Papyrus() implementation will look something like this. You'll need to figure out the right values for each category, this is just an example:

struct Papyrus: ViewModifier {
    @Environment(\.sizeCategory) var sizeCategory
    var textStyle: Font.TextStyle

    init(_ textStyle: Font.TextStyle = .body) {
        self.textStyle = textStyle
    }

    func body(content: Content) -> some View {
        content.font(getFont())
    }

    func getFont() -> Font {
        switch(sizeCategory) {
        case .extraSmall:
            return Font.custom("Papyrus", size: 16 * getStyleFactor())
        case .small:
            return Font.custom("Papyrus", size: 21 * getStyleFactor())
        case .medium:
            return Font.custom("Papyrus", size: 24 * getStyleFactor())
        case .large:
            return Font.custom("Papyrus", size: 28 * getStyleFactor())
        case .extraLarge:
            return Font.custom("Papyrus", size: 32 * getStyleFactor())
        case .extraExtraLarge:
            return Font.custom("Papyrus", size: 36 * getStyleFactor())
        case .extraExtraExtraLarge:
            return Font.custom("Papyrus", size: 40 * getStyleFactor())
        case .accessibilityMedium:
            return Font.custom("Papyrus", size: 48 * getStyleFactor())
        case .accessibilityLarge:
            return Font.custom("Papyrus", size: 52 * getStyleFactor())
        case .accessibilityExtraLarge:
            return Font.custom("Papyrus", size: 60 * getStyleFactor())
        case .accessibilityExtraExtraLarge:
            return Font.custom("Papyrus", size: 66 * getStyleFactor())
        case .accessibilityExtraExtraExtraLarge:
            return Font.custom("Papyrus", size: 72 * getStyleFactor())
        @unknown default:
            return Font.custom("Papyrus", size: 36 * getStyleFactor())
        }
    }

    func getStyleFactor() -> CGFloat {
        switch textStyle {
        case .caption:
            return 0.6
        case .footnote:
            return 0.7
        case .subheadline:
            return 0.8
        case .callout:
            return 0.9
        case .body:
            return 1.0
        case .headline:
            return 1.2
        case .title:
            return 1.5
        case .largeTitle:
            return 2.0
        @unknown default:
            return 1.0
        }
    }
