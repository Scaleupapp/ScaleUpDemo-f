import SwiftUI

// MARK: - CodeBlock model

/// A single parsed code block from a markdown-style brief.
struct CodeBlock: Hashable, Sendable {
    let filename: String?    // e.g. "users.js" if first line is `// users.js`
    let language: String?    // e.g. "javascript"
    let content: String

    /// Parse all markdown ``` ... ``` code blocks from a brief string.
    /// Returns blocks in source order. Returns empty array if none found.
    /// - If the first line of a block is a comment like `// foo.js` or `# foo.py`
    ///   (no spaces in the name, has a dot extension), that line is used as the
    ///   filename and stripped from `content`.
    static func parse(from text: String) -> [CodeBlock] {
        var blocks: [CodeBlock] = []
        let pattern = "```([a-zA-Z0-9_+\\-]*)[ \\t]*\\n([\\s\\S]*?)```"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, range: range)

        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }
            let langRange = match.range(at: 1)
            let contentRange = match.range(at: 2)

            let lang = langRange.location != NSNotFound
                ? nsText.substring(with: langRange)
                : ""
            var content = contentRange.location != NSNotFound
                ? nsText.substring(with: contentRange)
                : ""

            // Trim trailing newlines from the code body
            while content.hasSuffix("\n") { content.removeLast() }

            // Try to extract filename from the first line if it looks like a comment path
            var filename: String? = nil
            let firstLine = content.components(separatedBy: "\n").first ?? ""
            let trimmedFirst = firstLine.trimmingCharacters(in: .whitespaces)
            if trimmedFirst.hasPrefix("// ") || trimmedFirst.hasPrefix("# ") {
                let candidate = trimmedFirst
                    .replacingOccurrences(of: "^// ", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "^# ", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                // Accept as filename if: has an extension dot, no spaces, reasonably short
                if candidate.contains(".") && !candidate.contains(" ") && candidate.count < 60 {
                    filename = candidate
                    let rest = content.components(separatedBy: "\n").dropFirst().joined(separator: "\n")
                    // Trim a leading blank line left after stripping the filename comment
                    content = rest.hasPrefix("\n") ? String(rest.dropFirst()) : rest
                }
            }

            blocks.append(CodeBlock(
                filename: filename,
                language: lang.isEmpty ? nil : lang,
                content: content
            ))
        }
        return blocks
    }

    /// Strip ALL code blocks from a brief, returning only the prose around them.
    /// Collapses 3+ consecutive blank lines down to 2 and trims the result.
    static func stripCodeBlocks(from text: String) -> String {
        let pattern = "```[a-zA-Z0-9_+\\-]*[ \\t]*\\n[\\s\\S]*?```"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        let stripped = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
        // Collapse excess blank lines and trim
        let collapsed = stripped.replacingOccurrences(
            of: "\\n{3,}", with: "\n\n", options: .regularExpression
        )
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - CodeViewer view

/// Renders one or more `CodeBlock` values with a line-number gutter,
/// monospaced text, and horizontal+vertical scroll bounded to 320 pt height.
/// Multiple blocks get a file-tab strip at the top.
struct CodeViewer: View {
    let blocks: [CodeBlock]
    @State private var selectedBlock = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if blocks.count > 1 {
                fileTabs
            }
            if blocks.indices.contains(selectedBlock) {
                codeContent(blocks[selectedBlock])
            }
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: Tab strip (multi-file)

    private var fileTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { idx, block in
                    Button {
                        selectedBlock = idx
                    } label: {
                        Text(block.filename ?? block.language ?? "file \(idx + 1)")
                            .font(.caption.monospaced())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                selectedBlock == idx
                                    ? Color.accentColor.opacity(0.15)
                                    : Color.clear
                            )
                            .foregroundStyle(
                                selectedBlock == idx
                                    ? Color.accentColor
                                    : Color.secondary
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxHeight: 36)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 0.5)
        }
    }

    // MARK: Code content with line-number gutter

    private func codeContent(_ block: CodeBlock) -> some View {
        let lines = block.content.components(separatedBy: "\n")
        // Width of gutter = digit count of last line number * ~9 pt + 14 pt padding
        let lineNumberWidth: CGFloat = CGFloat(String(lines.count).count) * 9 + 14

        return ScrollView([.horizontal, .vertical], showsIndicators: true) {
            HStack(alignment: .top, spacing: 0) {
                // Gutter
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { idx, _ in
                        Text("\(idx + 1)")
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(Color.secondary.opacity(0.55))
                            .frame(width: lineNumberWidth, alignment: .trailing)
                            .padding(.trailing, 8)
                            .frame(height: 20)
                    }
                }
                .padding(.vertical, 10)
                .background(Color.gray.opacity(0.05))

                // Code lines
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line.isEmpty ? " " : line)
                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                            .fixedSize(horizontal: true, vertical: false)
                            .textSelection(.enabled)
                            .padding(.horizontal, 10)
                            .frame(height: 20, alignment: .leading)
                    }
                }
                .padding(.vertical, 10)
            }
        }
        .frame(maxHeight: 320)
    }
}

// MARK: - Preview

#Preview("Single file") {
    let brief = """
    Here is the buggy code:

    ```javascript
    // users.js
    function filterAdults(users) {
        return users.filter(user => {
            return user.age >= 18;
        });
    }

    function getNames(users) {
        return users.map(u => u.name)
    }
    ```

    Find all the bugs.
    """
    let blocks = CodeBlock.parse(from: brief)
    return CodeViewer(blocks: blocks)
        .padding()
}

#Preview("Multi-file") {
    let brief = """
    ```javascript
    // users.js
    function filterAdults(users) {
        return users.filter(user => user.age >= 18);
    }
    ```

    ```javascript
    // users.test.js
    test('filters adults', () => {
        expect(filterAdults([{age: 17}, {age: 20}])).toHaveLength(1);
    });
    ```
    """
    let blocks = CodeBlock.parse(from: brief)
    return CodeViewer(blocks: blocks)
        .padding()
}
