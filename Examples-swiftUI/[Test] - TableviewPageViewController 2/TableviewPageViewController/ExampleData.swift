import Foundation

//
// MARK: - Section Data Structure
//
public struct Item {
    var name: String
    var detail: String
    
    public init(name: String, detail: String) {
        self.name = name
        self.detail = detail
    }
}

public struct Section {
    var name: String
    var items: [Item]
    
    public init(name: String, items: [Item], collapsed: Bool = false) {
        self.name = name
        self.items = items
    }
}

public var sectionsData: [Section] = [
    Section(name: "Mac", items: [
        Item(name: "MacBook", detail: "Apple's ultraportable laptop, trading portability for speed and connectivity."),
        Item(name: "MacBook Air", detail: "While the screen could be sharper, the updated 11-inch MacBook Air is a very light ultraportable that offers great performance and battery life for the price."),
        Item(name: "MacBook Pro", detail: "Retina Display The brightest, most colorful Mac notebook display ever. The display in the MacBook Pro is the best ever in a Mac notebook."),
        Item(name: "iMac", detail: "iMac combines enhanced performance with our best ever Retina display for the ultimate desktop experience in two sizes."),
        Item(name: "Mac Pro", detail: "Mac Pro is equipped with pro-level graphics, storage, expansion, processing power, and memory. It's built for creativity on an epic scale."),
        Item(name: "Mac mini", detail: "Mac mini is an affordable powerhouse that packs the entire Mac experience into a 7.7-inch-square frame."),
        Item(name: "OS X El Capitan", detail: "The twelfth major release of OS X (now named macOS)."),
        Item(name: "Accessories", detail: "")
    ]),
    Section(name: "iPhone", items: [
        Item(name: "iPhone 6s",
             detail: "The iPhone 6S has a similar design to the 6 but updated hardware, including a strengthened chassis and upgraded system-on-chip, a 12-megapixel camera, improved fingerprint recognition sensor, and LTE Advanced support."),
        Item(name: "iPhone 6",
             detail: "The iPhone 6 and iPhone 6 Plus are smartphones designed and marketed by Apple Inc."),
        Item(name: "iPhone SE",
             detail: "The iPhone SE was received positively by critics, who noted its familiar form factor and design, improved hardware over previous 4-inch iPhone models, as well as its overall performance and battery life."),
        Item(name: "iPhone 7",
             detail: "The iPhone 7 and iPhone 7 Plus are smartphones that were designed, developed, and marketed by Apple Inc. They are the tenth generation of the iPhone."),
        Item(name: "iPhone 7 plus",
             detail: "The iPhone 7 and iPhone 7 Plus are smartphones that were designed, developed, and marketed by Apple Inc. They are the tenth generation of the iPhone."),
        Item(name: "iPhone 8",
             detail: "The iPhone 8 and iPhone 8 Plus[a] are smartphones designed, developed, and marketed by Apple Inc. They are the eleventh generation of the iPhone. The iPhone 8 was released on September 22, 2017, succeeding the iPhone 7 and iPhone 7 Plus respectively[8] and preceding the iPhone XR."),
        Item(name: "iPhone 8 plus",
             detail: "The iPhone 8 Plus is a large smartphone that was announced by Apple in a special event on September 12, 2017 alongside the iPhone 8 and X.[1] It was released on the following September 22nd as the successor to the iPhone 7 Plus"),
        Item(name: "iPhone X",
             detail: "The iPhone X (Roman numeral X pronounced ten [11]) is a smartphone designed, developed and marketed by Apple Inc. It is part of the eleventh generation of the iPhone. Available for pre-order from October 27, 2017, it was released on November 3, 2017. The naming of the iPhone X (skipping the iPhone 9) is to mark the 10th anniversary of the iPhone"),
        Item(name: "iPhone 11", detail: "The iPhone 11 is a smartphone designed, developed, and marketed by Apple Inc. It is the thirteenth generation of iPhone, succeeding the iPhone XR, and was unveiled on September 10, 2019, alongside the higher-end iPhone 11 Pro at the Steve Jobs Theater in Apple Park, Cupertino, by Apple CEO Tim Cook. Preorders began on September 13, 2019, and the phone was officially released on September 20, 2019, one day after the official public release of iOS 13."),
        Item(name: "iPhone 11 Pro", detail: "The iPhone 11 Pro and iPhone 11 Pro Max are smartphones designed, developed and marketed by Apple Inc. Serving as Apple's flagship models of the 13th generation of iPhones, they succeeded the iPhone XS and iPhone XS Max, respectively, upon their release. Apple CEO Tim Cook unveiled the devices alongside the standard model, the iPhone 11, on September 10, 2019 at the Steve Jobs Theater at Apple Park. Pre-orders began on September 13, 2019, and the phones went on sale on September 20"),
        Item(name: "Accessories", detail: "")
    ]),
    Section(name: "iPad", items: [
        Item(name: "iPad Pro", detail: "iPad Pro delivers epic power, in 12.9-inch and a new 10.5-inch size."),
        Item(name: "iPad Air 2", detail: "The second-generation iPad Air tablet computer designed, developed, and marketed by Apple Inc."),
        Item(name: "iPad mini 4", detail: "iPad mini 4 puts uncompromising performance and potential in your hand."),
        Item(name: "iPad mini 4", detail: "iPad mini 4 puts uncompromising performance and potential in your hand."),
        Item(name: "iPad mini 4", detail: "iPad mini 4 puts uncompromising performance and potential in your hand."),
        Item(name: "iPad mini 4", detail: "iPad mini 4 puts uncompromising performance and potential in your hand."),
        Item(name: "iPad mini 4", detail: "iPad mini 4 puts uncompromising performance and potential in your hand."),
        Item(name: "iPad mini 4", detail: "iPad mini 4 puts uncompromising performance and potential in your hand."),
        Item(name: "iPad mini 4", detail: "iPad mini 4 puts uncompromising performance and potential in your hand."),
        Item(name: "iPad mini 4", detail: "iPad mini 4 puts uncompromising performance and potential in your hand."),
        Item(name: "iPad mini 4", detail: "iPad mini 4 puts uncompromising performance and potential in your hand."),
        Item(name: "iPad mini 4", detail: "iPad mini 4 puts uncompromising performance and potential in your hand."),
        Item(name: "iPad mini 4", detail: "iPad mini 4 puts uncompromising performance and potential in your hand."),
        Item(name: "iPad mini 4", detail: "iPad mini 4 puts uncompromising performance and potential in your hand."),
        Item(name: "iPad mini 4", detail: "iPad mini 4 puts uncompromising performance and potential in your hand."),
        Item(name: "iPad mini 4", detail: "iPad mini 4 puts uncompromising performance and potential in your hand."),
        Item(name: "iPad mini 4", detail: "iPad mini 4 puts uncompromising performance and potential in your hand."),
        Item(name: "iPad mini 4", detail: "iPad mini 4 puts uncompromising performance and potential in your hand."),
        Item(name: "iPad mini 4", detail: "iPad mini 4 puts uncompromising performance and potential in your hand.")
    ]),
]
