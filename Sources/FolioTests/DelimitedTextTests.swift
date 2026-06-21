import Foundation
import FolioCore

func runDelimitedTextTests() {
    T.test("parses simple comma rows") {
        T.equal(DelimitedText.parse("a,b\n1,2", delimiter: ","), [["a", "b"], ["1", "2"]])
    }
    T.test("handles quoted fields containing the delimiter") {
        T.equal(DelimitedText.parse("\"a,b\",c", delimiter: ","), [["a,b", "c"]])
    }
    T.test("handles escaped double-quotes inside quotes") {
        T.equal(DelimitedText.parse("\"a\"\"b\",c", delimiter: ","), [["a\"b", "c"]])
    }
    T.test("handles newlines inside quoted fields") {
        T.equal(DelimitedText.parse("\"x\ny\",b", delimiter: ","), [["x\ny", "b"]])
    }
    T.test("supports tab delimiter and trailing newline") {
        T.equal(DelimitedText.parse("a\tb\n1\t2\n", delimiter: "\t"), [["a", "b"], ["1", "2"]])
    }
    T.test("handles CRLF line endings") {
        T.equal(DelimitedText.parse("a,b\r\n1,2", delimiter: ","), [["a", "b"], ["1", "2"]])
    }
}
