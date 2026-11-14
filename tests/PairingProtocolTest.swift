import Foundation
@main struct PairingProtocolTest {
    static func main() {
        precondition(PairingProtocol.validCode("000123"))
        for code in ["12345", "1234567", "１２３４５６", "123 56", "abcdef"] { precondition(!PairingProtocol.validCode(code)) }
        precondition(PairingProtocol.baseURL("http://192.168.219.100:8765") != nil)
        precondition(PairingProtocol.baseURL("http://10.0.0.1:8765/") != nil)
        for address in ["http://8.8.8.8:8765", "http://192.168.1.1:80", "http://192.168.1.1:8765/fix", "http://user@192.168.1.1:8765", "http://192.168.1.1:8765?a=1", "http://192.168..1:8765", "http://010.0.0.1:8765"] { precondition(PairingProtocol.baseURL(address) == nil) }
        let token = "0123456789abcdef0123456789abcdef"
        precondition(PairingProtocol.token(from: Data("{\"token\":\"\(token)\"}".utf8)) == token)
        precondition(PairingProtocol.token(from: Data("{\"token\":\"bad\"}".utf8)) == nil)
        for status in [401,409,410,429,404] { precondition(!PairingProtocol.errorMessage(status).isEmpty) }
        print("PASS 23 iPhone pairing protocol checks")
    }
}
