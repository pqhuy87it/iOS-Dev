import UIKit

class ViewController: UIViewController {
    @IBOutlet var lbText: UILabel!
    
    private enum Constant {
        static let BACKGROUND_CORNER_RADIUS: CGFloat = 18.0
        
        static let INFO_VIEW_CORNER_RADIUS: CGFloat = 8.0
        
        static let DIVISION_LABEL_CORNER_RADIUS: CGFloat = 2.0
        
        static let ICON_CARD_CORNER_RADIUS: CGFloat = 2.0
        
        static let BACKGROUND_BORDER_WIDTH: CGFloat = 1.0
        
        static let FAMILY_CORNER_RADIUS: CGFloat = 4.0
        
        static let SHADOW_RADIUS = 2.0
        static let SHADOW_OPACITY = Float(0.06)
        static let SHADOW_COLOR = UIColor.black
        static let SHADOW_OFFSET = CGSize(width: 0, height: 2)
        
        static let NOTICE_LABEL_FONT_NAME: String = "HiraKakuProN-W3"
        static let NOTICE_LABEL_FONT_SIZE: CGFloat = 12
        static let NOTICE_LABEL_LIGHT_HEIGHT: CGFloat = 0.0
        static let NOTICE_LABEL_LIGHT_SPACING: CGFloat = 6.0
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        let textStr = "端末のサイズが小さかったり、文言がかなり長い場合に3行に折り返すこともあります。端末のサイズが小さかったり、文言がかなり長い場合に3行に折り返すこともあります。端末のサイズが小さかったり、文言がかなり長い場合に3行に折り返すこともあります。端末のサイズが小さかったり、文言がかなり長い場合に3行に折り返すこともあります。端末のサイズが小さかったり、文言がかなり長い場合に3行に折り返すこともあります。"

        self.remakeToHtmlFormatLabel(self.lbText,
                                     htmlText: textStr,
                                     fontName: Constant.NOTICE_LABEL_FONT_NAME,
                                     fontSize: Constant.NOTICE_LABEL_FONT_SIZE,
                                     lineHeight: Constant.NOTICE_LABEL_LIGHT_HEIGHT,
                                     lineSpacing: Constant.NOTICE_LABEL_LIGHT_SPACING,
                                     textColor: UIColor.gray)
        
        self.lbText.layoutIfNeeded()
        let numberLine = self.lbText.maxNumberOfLines
        print(numberLine)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        print(lbText.actualNumberOfLines)
    }

    func remakeToHtmlFormatLabel(_ label: UILabel,
                                 htmlText: String,
                                 fontName: String,
                                 fontSize: CGFloat,
                                 lineHeight: CGFloat,
                                 lineSpacing: CGFloat,
                                 textColor: UIColor?)
    {
        let systemFont = UIFont.systemFont(ofSize: fontSize)
        let font = UIFont(name: fontName,
                          size: fontSize) ?? systemFont
        let attributedText: String

        if let textColor = textColor {
            let hexFormat = textColor.getHtmlHexFormattedString()
            attributedText = "<SPAN style='color:#\(hexFormat);'>\(htmlText)</SPAN>"
                + "<style>"
                + "*{"
                + "  font-family:'\(font.fontName)';"
                + "  font-size:\(font.pointSize)px;"
                + "  line-height:\(lineHeight)px;"
                + "}"
                + "</style>"
        } else {
            attributedText = htmlText
                + "<style>"
                + "*{"
                + "  font-family:'\(font.fontName)';"
                + "  font-size:\(font.pointSize)px;"
                + "  line-height:\(lineHeight)px;"
                + "}"
                + "</style>"
        }

        // attributedText を設定すると、textAlignment 等の情報が消えるので、
        // 事前に textAlignment 等を退避しておき、attributedText を設定した後に、復元する。
        let textAlignment = label.textAlignment
        let lineBreakMode = label.lineBreakMode

        let attributedString = try? NSMutableAttributedString(
            data: attributedText.data(using: String.Encoding.unicode) ?? Data(),
            options: [NSAttributedString.DocumentReadingOptionKey.documentType:
                NSAttributedString.DocumentType.html],
            documentAttributes: nil
        )

        // Line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        attributedString?.addAttribute(NSAttributedString.Key.paragraphStyle,
                                       value: paragraphStyle,
                                       range: NSMakeRange(0, attributedString?.length ?? 0))

        label.attributedText = attributedString
        label.textAlignment = textAlignment
        label.lineBreakMode = lineBreakMode
    }
}

extension NSAttributedString {
    /// Get the number of lines an attributed string takes
    func lineCount(atSize size: CGSize) -> Int {
        let attrs = self.attributes(at: 0, effectiveRange: nil)
        guard let font = (attrs[NSAttributedString.Key.font] as? UIFont) else {
            return 0
        }
        let paragraph = attrs[NSAttributedString.Key.paragraphStyle] as? NSParagraphStyle
        let fontMultiplyer = 1.0 // paragraph?.lineHeightMultiple ?? 1.0
        let lineSpacing = paragraph?.lineSpacing ?? 0
        
        // Take the font's lineHeight, multiply it by the lineHeightMultiplyer and add lineSpacing
        // (Linespacing is maybe wrong here?) to get height of a single line
        let singleLineHeight = ceil(font.lineHeight * fontMultiplyer + lineSpacing)
        
        // Get our own text height
        let textHeight = self.boundingRect(with: size, options: .usesLineFragmentOrigin, context: nil).height
        return Int(ceil(textHeight / singleLineHeight))
    }
    
    func truncated(withAttrString truncation: NSAttributedString, atLine numLines: Int, width: CGFloat) -> NSAttributedString {
        if self.lineCount(atSize: CGSize(width: width, height: CGFloat.infinity)) <= numLines {
            // Smaller than number of lines we care about
            return self
        }
        
        var subAttr = NSMutableAttributedString()
        var lastEnd = 0
        
        // 1. Enumerate through words
        (self.string as NSString).enumerateSubstrings(in: NSMakeRange(0, self.string.count), options: .byWords) { _, strRange, strRangeWithEnd, stop in
            // 2. Add the word (without the whitespace) and the truncation string (ie. "... more") to the str
            subAttr.append(self.attributedSubstring(from: strRange))
            subAttr.append(truncation)
            
            // 3. See if that attributed string is too many lines
            if subAttr.lineCount(atSize: CGSize(width: width, height: CGFloat.infinity)) > numLines {
                // 3a. If it is then delete the last word (and any whitespace before it) but leave the truncation string
                
                // We need to delete to the end of the previous range (and then add the difference to the length of the range) because there can be multiple whitespace characters together
                subAttr.deleteCharacters(in: NSMakeRange(lastEnd, strRange.length + (strRange.location - lastEnd)))
                stop.pointee = true
            } else {
                // 3b. If it is too short track the end of this (for sake of deleting whitespace on next pass),
                //     delete the word from the end and then add the word + whitespace and go back to #2
                lastEnd = strRange.location + strRange.length
                let deleteRange = NSMakeRange(strRange.location, strRange.length + truncation.length)
                subAttr.deleteCharacters(in: deleteRange)
                subAttr.append(self.attributedSubstring(from: strRangeWithEnd))
            }
        }
        return subAttr
    }
}

extension UILabel {
    var maxNumberOfLines: Int {
        layoutIfNeeded() // important
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6.0
        
        let font = UIFont(name: "HiraKakuProN-W3", size: 12)!
        let maxSize = CGSize(width: frame.size.width, height: CGFloat(MAXFLOAT))
        let text = (self.text ?? "") as NSString
        let textHeight = text.boundingRect(with: maxSize,
                                           options: .usesLineFragmentOrigin,
                                           attributes: [NSAttributedString.Key.paragraphStyle: paragraphStyle,
                                                        NSAttributedString.Key.font: font], context: nil).height
        let lineHeight = ceil(font.lineHeight * 1 + 6.0) // font.lineHeight
        return Int(ceil(textHeight / lineHeight))
    }
}

extension NSAttributedString {
    /// Số line thực tế khi layout trong chiều rộng cho trước.
    func numberOfLines(constrainedTo width: CGFloat) -> Int {
        guard length > 0, width > 0 else { return 0 }

        // Copy và ép lineBreakMode về wrapping,
        // vì truncating mode làm CTFramesetter chỉ sinh 1 line.
        let measured = NSMutableAttributedString(attributedString: self)
        let full = NSRange(location: 0, length: length)
        enumerateAttribute(.paragraphStyle, in: full) { value, range, _ in
            let style = (value as? NSParagraphStyle)?
                .mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            style.lineBreakMode = .byWordWrapping   // CJK vẫn break đúng theo Unicode rules
            measured.addAttribute(.paragraphStyle, value: style, range: range)
        }

        let path = CGPath(rect: CGRect(x: 0, y: 0, width: width, height: 100_000),
                          transform: nil)
        let framesetter = CTFramesetterCreateWithAttributedString(measured)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
        return (CTFrameGetLines(frame) as NSArray).count
    }
}

extension UILabel {
    var actualNumberOfLines: Int {
        guard let attributed = attributedText else { return 0 }
        return attributed.numberOfLines(constrainedTo: bounds.width)
    }
}

extension UIColor {
    /// Retruns R, G, B, A components from UIColor values.
    var rgbaComponent: [CGFloat] {
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 0.0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        
        // inside the sRGB color gamut.
        // see: https://developer.apple.com/documentation/uikit/uicolor/1621919-getred
        return [r, g, b, a].map { f -> CGFloat in
            switch f {
            case let f where f < 0.0:
                return 0.0
            case let f where f > 1.0:
                return 1.0
            default:
                return f
            }
        }
    }
    
    /// Gets the color as HTML hex formatted string.
    /// Currently, this method supports only the sRGB color space out of the color spaces that can be defined by UIColor.
    /// 自分自身の色を、HTMLの16進数形式で返す
    /// 現状このメソッドでは、UIColor で定義できる色空間のうち、sRGB色空間のみ対応している。
    ///
    /// - returns: the formatted string
    func getHtmlHexFormattedString() -> String {
        let components = self.rgbaComponent
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        let a = Float(components[3])

        return String(format: "%02lX%02lX%02lX%02lX",
                      lroundf(r * 255),
                      lroundf(g * 255),
                      lroundf(b * 255),
                      lroundf(a * 255))
    }
}
