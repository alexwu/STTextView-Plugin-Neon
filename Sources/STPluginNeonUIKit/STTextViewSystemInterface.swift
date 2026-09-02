import UIKit
import STTextViewUIKit
import Neon

class STTextViewSystemInterface: TextSystemInterface {

    typealias AttributeProvider = (Neon.Token) -> [NSAttributedString.Key: Any]?

    private let textView: STTextView
    private let attributeProvider: AttributeProvider

    init(textView: STTextView, attributeProvider: @escaping AttributeProvider) {
        self.textView = textView
        self.attributeProvider = attributeProvider
    }

    func clearStyle(in range: NSRange) {
        guard let textRange = NSTextRange(range, in: textView.textContentManager) else {
            assertionFailure()
            return
        }

        textView.textLayoutManager.removeRenderingAttribute(.foregroundColor, for: textRange)
        textView.addAttributes([.font: textView.font], range: range)
    }

    func applyStyle(to token: Neon.Token) {
        // tree-sitter grammars (notably tree-sitter-markdown via `block_continuation`
        // and friends) emit zero-width nodes whose captures arrive here as tokens
        // with `range.length == 0`. Forwarding a zero-length range to
        // `NSTextLayoutManager.addRenderingAttribute(_:value:for:)` or
        // `NSMutableAttributedString.addAttributes(_:range:)` can crash Foundation
        // with `*** -[__NSPlaceholderArray initWithObjects:count:]: attempt to
        // insert nil object from objects[0]` when the attribute-span normalisation
        // builds an internal NSArray for the empty span. Skip them — they're
        // structural anchors, not visible glyphs.
        guard token.range.length > 0 else { return }

        guard let attrs = attributeProvider(token),
              let textRange = NSTextRange(token.range, in: textView.textContentManager)
        else {
            return
        }

        for attr in attrs {
            if attr.key == .foregroundColor {
                textView.textLayoutManager.addRenderingAttribute(.foregroundColor, value: attr.value, for: textRange)
            } else {
                textView.addAttributes([attr.key: attr.value], range: token.range)
            }
        }
    }

    var length: Int {
        textView.textContentManager.length
    }

    var visibleRange: NSRange {
        guard let viewportRange = textView.textLayoutManager.textViewportLayoutController.viewportRange else {
            return .zero
        }

        return NSRange(viewportRange, provider: textView.textContentManager)
    }
}
