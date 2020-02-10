//  SwiftyJSON.swift
//
//  Copyright (c) 2014 - 2016 Ruoyu Fu, Pinglin Tang
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation

// MARK: - Error

///Error domain
internal let ErrorDomain: String = "SwiftyJSONErrorDomain"

///Error code
internal let ErrorUnsupportedType: Int = 999
internal let ErrorIndexOutOfBounds: Int = 900
internal let ErrorWrongType: Int = 901
internal let ErrorNotExist: Int = 500
internal let ErrorInvalidJSON: Int = 490

// MARK: - JSON Type

/**
 JSON's type definitions.

 See http://www.json.org
 */
internal enum Type :Int{

    case number
    case string
    case bool
    case array
    case dictionary
    case null
    case unknown
}

// MARK: - JSON Base
internal struct JSON {

    /**
     Creates a JSON using the data.

     - parameter data:  The NSData used to convert to json.Top level object in data is an NSArray or NSDictionary
     - parameter opt:   The JSON serialization reading options. `.AllowFragments` by default.
     - parameter error: The NSErrorPointer used to return the error. `nil` by default.

     - returns: The created JSON
     */
    internal init(data:Data, options opt: JSONSerialization.ReadingOptions = .allowFragments, error: NSErrorPointer = nil) {
        do {
            let object: Any = try JSONSerialization.jsonObject(with: data, options: opt)
            self.init(object)
        } catch let aError as NSError {
            if error != nil {
                error?.pointee = aError
            }
            self.init(NSNull())
        }
    }

    /**
     Creates a JSON from JSON string
     - parameter string: Normal json string like '{"a":"b"}'

     - returns: The created JSON
     */
    internal static func parse(_ string:String) -> JSON {
        return string.data(using: String.Encoding.utf8)
            .flatMap{ JSON(data: $0) } ?? JSON(NSNull())
    }

    /**
     Creates a JSON using the object.

     - parameter object:  The object must have the following properties: All objects are NSString/String, NSNumber/Int/Float/Double/Bool, NSArray/Array, NSDictionary/Dictionary, or NSNull; All dictionary keys are NSStrings/String; NSNumbers are not NaN or infinity.

     - returns: The created JSON
     */
    internal init(_ object: Any) {
        self.object = object
    }

    /**
     Creates a JSON from a [JSON]

     - parameter jsonArray: A Swift array of JSON objects

     - returns: The created JSON
     */
    internal init(_ jsonArray:[JSON]) {
        self.init(jsonArray.map { $0.object })
    }

    /**
     Creates a JSON from a [String: JSON]

     - parameter jsonDictionary: A Swift dictionary of JSON objects

     - returns: The created JSON
     */
    internal init(_ jsonDictionary:[String: JSON]) {
        var dictionary = [String: Any](minimumCapacity: jsonDictionary.count)
        for (key, json) in jsonDictionary {
            dictionary[key] = json.object
        }
        self.init(dictionary)
    }

    /// Private object
    fileprivate var rawArray: [Any] = []
    fileprivate var rawDictionary: [String : Any] = [:]
    fileprivate var rawString: String = ""
    fileprivate var rawNumber: NSNumber = 0
    fileprivate var rawNull: NSNull = NSNull()
    fileprivate var rawBool: Bool = false
    /// Private type
    fileprivate var _type: Type = .null
    /// prviate error
    fileprivate var _error: NSError? = nil

    /// Object in JSON
    internal var object: Any {
        get {
            switch self.type {
            case .array:
                return self.rawArray
            case .dictionary:
                return self.rawDictionary
            case .string:
                return self.rawString
            case .number:
                return self.rawNumber
            case .bool:
                return self.rawBool
            default:
                return self.rawNull
            }
        }
        set {
            _error = nil
            switch newValue {
            case let number as NSNumber:
                if number.isBool {
                    _type = .bool
                    self.rawBool = number.boolValue
                } else {
                    _type = .number
                    self.rawNumber = number
                }
            case  let string as String:
                _type = .string
                self.rawString = string
            case  _ as NSNull:
                _type = .null
            case let array as [JSON]:
                _type = .array
                self.rawArray = array.map { $0.object }
            case let array as [Any]:
                _type = .array
                self.rawArray = array
            case let dictionary as [String : Any]:
                _type = .dictionary
                self.rawDictionary = dictionary
            default:
                _type = .unknown
                _error = NSError(domain: ErrorDomain, code: ErrorUnsupportedType, userInfo: [NSLocalizedDescriptionKey: "It is a unsupported type"])
            }
        }
    }

    /// JSON type
    internal var type: Type { get { return _type } }

    /// Error in JSON
    internal var error: NSError? { get { return self._error } }

    /// The static null JSON
    @available(*, unavailable, renamed:"null")
    internal static var nullJSON: JSON { get { return null } }
    internal static var null: JSON { get { return JSON(NSNull()) } }
}

internal enum JSONIndex:Comparable
{
    case array(Int)
    case dictionary(DictionaryIndex<String, JSON>)
    case null

    static internal func ==(lhs: JSONIndex, rhs: JSONIndex) -> Bool
    {
        switch (lhs, rhs)
        {
        case (.array(let left), .array(let right)):
            return left == right
        case (.dictionary(let left), .dictionary(let right)):
            return left == right
        case (.null, .null): return true
        default:
            return false
        }
    }

    static internal func <(lhs: JSONIndex, rhs: JSONIndex) -> Bool
    {
        switch (lhs, rhs)
        {
        case (.array(let left), .array(let right)):
            return left < right
        case (.dictionary(let left), .dictionary(let right)):
            return left < right
        default:
            return false
        }
    }

}

internal enum JSONRawIndex: Comparable
{
    case array(Int)
    case dictionary(DictionaryIndex<String, Any>)
    case null

    static internal func ==(lhs: JSONRawIndex, rhs: JSONRawIndex) -> Bool
    {
        switch (lhs, rhs)
        {
        case (.array(let left), .array(let right)):
            return left == right
        case (.dictionary(let left), .dictionary(let right)):
            return left == right
        case (.null, .null): return true
        default:
            return false
        }
    }

    static internal func <(lhs: JSONRawIndex, rhs: JSONRawIndex) -> Bool
    {
        switch (lhs, rhs)
        {
        case (.array(let left), .array(let right)):
            return left < right
        case (.dictionary(let left), .dictionary(let right)):
            return left < right
        default:
            return false
        }
    }


}

extension JSON: Collection
{

    internal typealias Index = JSONRawIndex

    internal var startIndex: Index
    {
        switch type
        {
        case .array:
            return .array(rawArray.startIndex)
        case .dictionary:
            return .dictionary(rawDictionary.startIndex)
        default:
            return .null
        }
    }

    internal var endIndex: Index
    {
        switch type
        {
        case .array:
            return .array(rawArray.endIndex)
        case .dictionary:
            return .dictionary(rawDictionary.endIndex)
        default:
            return .null
        }
    }

    internal func index(after i: Index) -> Index
    {
        switch i
        {
        case .array(let idx):
            return .array(rawArray.index(after: idx))
        case .dictionary(let idx):
            return .dictionary(rawDictionary.index(after: idx))
        default:
            return .null
        }

    }

    internal subscript (position: Index) -> (String, JSON)
    {
        switch position
        {
        case .array(let idx):
            return (String(idx), JSON(self.rawArray[idx]))
        case .dictionary(let idx):
            let (key, value) = self.rawDictionary[idx]
            return (key, JSON(value))
        default:
            return ("", JSON.null)
        }
    }


}

// MARK: - Subscript

/**
 *  To mark both String and Int can be used in subscript.
 */
internal enum JSONKey
{
    case index(Int)
    case key(String)
}

internal protocol JSONSubscriptType {
    var jsonKey:JSONKey { get }
}

extension Int: JSONSubscriptType {
    internal var jsonKey:JSONKey {
        return JSONKey.index(self)
    }
}

extension String: JSONSubscriptType {
    internal var jsonKey:JSONKey {
        return JSONKey.key(self)
    }
}

extension JSON {

    /// If `type` is `.Array`, return json whose object is `array[index]`, otherwise return null json with error.
    fileprivate subscript(index index: Int) -> JSON {
        get {
            if self.type != .array {
                var r = JSON.null
                r._error = self._error ?? NSError(domain: ErrorDomain, code: ErrorWrongType, userInfo: [NSLocalizedDescriptionKey: "Array[\(index)] failure, It is not an array"])
                return r
            } else if index >= 0 && index < self.rawArray.count {
                return JSON(self.rawArray[index])
            } else {
                var r = JSON.null
                r._error = NSError(domain: ErrorDomain, code:ErrorIndexOutOfBounds , userInfo: [NSLocalizedDescriptionKey: "Array[\(index)] is out of bounds"])
                return r
            }
        }
        set {
            if self.type == .array {
                if self.rawArray.count > index && newValue.error == nil {
                    self.rawArray[index] = newValue.object
                }
            }
        }
    }

    /// If `type` is `.Dictionary`, return json whose object is `dictionary[key]` , otherwise return null json with error.
    fileprivate subscript(key key: String) -> JSON {
        get {
            var r = JSON.null
            if self.type == .dictionary {
                if let o = self.rawDictionary[key] {
                    r = JSON(o)
                } else {
                    r._error = NSError(domain: ErrorDomain, code: ErrorNotExist, userInfo: [NSLocalizedDescriptionKey: "Dictionary[\"\(key)\"] does not exist"])
                }
            } else {
                r._error = self._error ?? NSError(domain: ErrorDomain, code: ErrorWrongType, userInfo: [NSLocalizedDescriptionKey: "Dictionary[\"\(key)\"] failure, It is not an dictionary"])
            }
            return r
        }
        set {
            if self.type == .dictionary && newValue.error == nil {
                self.rawDictionary[key] = newValue.object
            }
        }
    }

    /// If `sub` is `Int`, return `subscript(index:)`; If `sub` is `String`,  return `subscript(key:)`.
    fileprivate subscript(sub sub: JSONSubscriptType) -> JSON {
        get {
            switch sub.jsonKey {
            case .index(let index): return self[index: index]
            case .key(let key): return self[key: key]
            }
        }
        set {
            switch sub.jsonKey {
            case .index(let index): self[index: index] = newValue
            case .key(let key): self[key: key] = newValue
            }
        }
    }

    /**
     Find a json in the complex data structures by using array of Int and/or String as path.

     - parameter path: The target json's path. Example:

     let json = JSON[data]
     let path = [9,"list","person","name"]
     let name = json[path]

     The same as: let name = json[9]["list"]["person"]["name"]

     - returns: Return a json found by the path or a null json with error
     */
    internal subscript(path: [JSONSubscriptType]) -> JSON {
        get {
            return path.reduce(self) { $0[sub: $1] }
        }
        set {
            switch path.count {
            case 0:
                return
            case 1:
                self[sub:path[0]].object = newValue.object
            default:
                var aPath = path; aPath.remove(at: 0)
                var nextJSON = self[sub: path[0]]
                nextJSON[aPath] = newValue
                self[sub: path[0]] = nextJSON
            }
        }
    }

    /**
     Find a json in the complex data structures by using array of Int and/or String as path.

     - parameter path: The target json's path. Example:

     let name = json[9,"list","person","name"]

     The same as: let name = json[9]["list"]["person"]["name"]

     - returns: Return a json found by the path or a null json with error
     */
    internal subscript(path: JSONSubscriptType...) -> JSON {
        get {
            return self[path]
        }
        set {
            self[path] = newValue
        }
    }
}

// MARK: - LiteralConvertible

extension JSON: Swift.ExpressibleByStringLiteral {

    internal init(stringLiteral value: StringLiteralType) {
        self.init(value as Any)
    }

    internal init(extendedGraphemeClusterLiteral value: StringLiteralType) {
        self.init(value as Any)
    }

    internal init(unicodeScalarLiteral value: StringLiteralType) {
        self.init(value as Any)
    }
}

extension JSON: Swift.ExpressibleByIntegerLiteral {

    internal init(integerLiteral value: IntegerLiteralType) {
        self.init(value as Any)
    }
}

extension JSON: Swift.ExpressibleByBooleanLiteral {

    internal init(booleanLiteral value: BooleanLiteralType) {
        self.init(value as Any)
    }
}

extension JSON: Swift.ExpressibleByFloatLiteral {

    internal init(floatLiteral value: FloatLiteralType) {
        self.init(value as Any)
    }
}

extension JSON: Swift.ExpressibleByDictionaryLiteral {
    internal init(dictionaryLiteral elements: (String, Any)...) {
        let array = elements
        self.init(dictionaryLiteral: array)
    }

    internal init(dictionaryLiteral elements: [(String, Any)]) {
        let jsonFromDictionaryLiteral: ([String : Any]) -> JSON = { dictionary in
            let initializeElement = Array(dictionary.keys).compactMap { key -> (String, Any)? in
                if let value = dictionary[key] {
                    return (key, value)
                }
                return nil
            }
            return JSON(dictionaryLiteral: initializeElement)
        }

        var dict = [String : Any](minimumCapacity: elements.count)

        for element in elements {
            let elementToSet: Any
            if let json = element.1 as? JSON {
                elementToSet = json.object
            } else if let jsonArray = element.1 as? [JSON] {
                elementToSet = JSON(jsonArray).object
            } else if let dictionary = element.1 as? [String : Any] {
                elementToSet = jsonFromDictionaryLiteral(dictionary).object
            } else if let dictArray = element.1 as? [[String : Any]] {
                let jsonArray = dictArray.map { jsonFromDictionaryLiteral($0) }
                elementToSet = JSON(jsonArray).object
            } else {
                elementToSet = element.1
            }
            dict[element.0] = elementToSet
        }

        self.init(dict)
    }
}

extension JSON: Swift.ExpressibleByArrayLiteral {

    internal init(arrayLiteral elements: Any...) {
        self.init(elements as Any)
    }
}

extension JSON: Swift.ExpressibleByNilLiteral {

    @available(*, deprecated, message: "use JSON.null instead. Will be removed in future versions")
    internal init(nilLiteral: ()) {
        self.init(NSNull() as Any)
    }
}

// MARK: - Raw

extension JSON: Swift.RawRepresentable {

    internal init?(rawValue: Any) {
        if JSON(rawValue).type == .unknown {
            return nil
        } else {
            self.init(rawValue)
        }
    }

    internal var rawValue: Any {
        return self.object
    }

    internal func rawData(options opt: JSONSerialization.WritingOptions = JSONSerialization.WritingOptions(rawValue: 0)) throws -> Data {
        guard JSONSerialization.isValidJSONObject(self.object) else {
            throw NSError(domain: ErrorDomain, code: ErrorInvalidJSON, userInfo: [NSLocalizedDescriptionKey: "JSON is invalid"])
        }

        return try JSONSerialization.data(withJSONObject: self.object, options: opt)
    }

    internal func rawString(_ encoding: String.Encoding = String.Encoding.utf8, options opt: JSONSerialization.WritingOptions = .prettyPrinted) -> String? {
        switch self.type {
        case .array, .dictionary:
            do {
                let data = try self.rawData(options: opt)
                return String(data: data, encoding: encoding)
            } catch _ {
                return nil
            }
        case .string:
            return self.rawString
        case .number:
            return self.rawNumber.stringValue
        case .bool:
            return self.rawBool.description
        case .null:
            return "null"
        default:
            return nil
        }
    }
}

// MARK: - Printable, DebugPrintable

extension JSON: Swift.CustomStringConvertible, Swift.CustomDebugStringConvertible {

    internal var description: String {
        if let string = self.rawString(options:.prettyPrinted) {
            return string
        } else {
            return "unknown"
        }
    }

    internal var debugDescription: String {
        return description
    }
}

// MARK: - Array

extension JSON {

    //Optional [JSON]
    internal var array: [JSON]? {
        get {
            if self.type == .array {
                return self.rawArray.map{ JSON($0) }
            } else {
                return nil
            }
        }
    }

    //Non-optional [JSON]
    internal var arrayValue: [JSON] {
        get {
            return self.array ?? []
        }
    }

    //Optional [Any]
    internal var arrayObject: [Any]? {
        get {
            switch self.type {
            case .array:
                return self.rawArray
            default:
                return nil
            }
        }
        set {
            if let array = newValue {
                self.object = array as Any
            } else {
                self.object = NSNull()
            }
        }
    }
}

// MARK: - Dictionary

extension JSON {

    //Optional [String : JSON]
    internal var dictionary: [String : JSON]? {
        if self.type == .dictionary {
            var d = [String : JSON](minimumCapacity: rawDictionary.count)
            for (key, value) in rawDictionary {
                d[key] = JSON(value)
            }
            return d
        } else {
            return nil
        }
    }

    //Non-optional [String : JSON]
    internal var dictionaryValue: [String : JSON] {
        return self.dictionary ?? [:]
    }

    //Optional [String : Any]

    internal var dictionaryObject: [String : Any]? {
        get {
            switch self.type {
            case .dictionary:
                return self.rawDictionary
            default:
                return nil
            }
        }
        set {
            if let v = newValue {
                self.object = v as Any
            } else {
                self.object = NSNull()
            }
        }
    }
}

// MARK: - Bool

extension JSON { // : Swift.Bool

    //Optional bool
    internal var bool: Bool? {
        get {
            switch self.type {
            case .bool:
                return self.rawBool
            default:
                return nil
            }
        }
        set {
            if let newValue = newValue {
                self.object = newValue as Bool
            } else {
                self.object = NSNull()
            }
        }
    }

    //Non-optional bool
    internal var boolValue: Bool {
        get {
            switch self.type {
            case .bool:
                return self.rawBool
            case .number:
                return self.rawNumber.boolValue
            case .string:
                return ["true", "y", "t"].contains() { (truthyString) in
                    return self.rawString.caseInsensitiveCompare(truthyString) == .orderedSame
                }
            default:
                return false
            }
        }
        set {
            self.object = newValue
        }
    }
}

// MARK: - String

extension JSON {

    //Optional string
    internal var string: String? {
        get {
            switch self.type {
            case .string:
                return self.object as? String
            default:
                return nil
            }
        }
        set {
            if let newValue = newValue {
                self.object = NSString(string:newValue)
            } else {
                self.object = NSNull()
            }
        }
    }

    //Non-optional string
    internal var stringValue: String {
        get {
            switch self.type {
            case .string:
                return self.object as? String ?? ""
            case .number:
                return self.rawNumber.stringValue
            case .bool:
                return (self.object as? Bool).map { String($0) } ?? ""
            default:
                return ""
            }
        }
        set {
            self.object = NSString(string:newValue)
        }
    }
}

// MARK: - Number
extension JSON {

    //Optional number
    internal var number: NSNumber? {
        get {
            switch self.type {
            case .number:
                return self.rawNumber
            case .bool:
                return NSNumber(value: self.rawBool ? 1 : 0)
            default:
                return nil
            }
        }
        set {
            self.object = newValue ?? NSNull()
        }
    }

    //Non-optional number
    internal var numberValue: NSNumber {
        get {
            switch self.type {
            case .string:
                let decimal = NSDecimalNumber(string: self.object as? String)
                if decimal == NSDecimalNumber.notANumber {  // indicates parse error
                    return NSDecimalNumber.zero
                }
                return decimal
            case .number:
                return self.object as? NSNumber ?? NSNumber(value: 0)
            case .bool:
                return NSNumber(value: self.rawBool ? 1 : 0)
            default:
                return NSNumber(value: 0.0)
            }
        }
        set {
            self.object = newValue
        }
    }
}

//MARK: - Null
extension JSON {

    internal var null: NSNull? {
        get {
            switch self.type {
            case .null:
                return self.rawNull
            default:
                return nil
            }
        }
        set {
            self.object = NSNull()
        }
    }
    internal func exists() -> Bool{
        if let errorValue = error, errorValue.code == ErrorNotExist ||
            errorValue.code == ErrorIndexOutOfBounds ||
            errorValue.code == ErrorWrongType {
                return false
        }
        return true
    }
}

//MARK: - URL
extension JSON {

    //Optional URL
    internal var URL: URL? {
        get {
            switch self.type {
            case .string:
                if let encodedString_ = self.rawString.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) {
                    // We have to use `Foundation.URL` otherwise it conflicts with the variable name.
                    return Foundation.URL(string: encodedString_)
                } else {
                    return nil
                }
            default:
                return nil
            }
        }
        set {
            self.object = newValue?.absoluteString ?? NSNull()
        }
    }
}

// MARK: - Int, Double, Float, Int8, Int16, Int32, Int64

extension JSON {

    internal var double: Double? {
        get {
            return self.number?.doubleValue
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object = NSNull()
            }
        }
    }

    internal var doubleValue: Double {
        get {
            return self.numberValue.doubleValue
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }

    internal var float: Float? {
        get {
            return self.number?.floatValue
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object = NSNull()
            }
        }
    }

    internal var floatValue: Float {
        get {
            return self.numberValue.floatValue
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }

    internal var int: Int?
    {
        get
        {
            return self.number?.intValue
        }
        set
        {
            if let newValue = newValue
            {
                self.object = NSNumber(value: newValue)
            } else
            {
                self.object = NSNull()
            }
        }
    }

    internal var intValue: Int {
        get {
            return self.numberValue.intValue
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }

    internal var uInt: UInt? {
        get {
            return self.number?.uintValue
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object = NSNull()
            }
        }
    }

    internal var uIntValue: UInt {
        get {
            return self.numberValue.uintValue
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }

    internal var int8: Int8? {
        get {
            return self.number?.int8Value
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object =  NSNull()
            }
        }
    }

    internal var int8Value: Int8 {
        get {
            return self.numberValue.int8Value
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }

    internal var uInt8: UInt8? {
        get {
            return self.number?.uint8Value
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object =  NSNull()
            }
        }
    }

    internal var uInt8Value: UInt8 {
        get {
            return self.numberValue.uint8Value
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }

    internal var int16: Int16? {
        get {
            return self.number?.int16Value
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object =  NSNull()
            }
        }
    }

    internal var int16Value: Int16 {
        get {
            return self.numberValue.int16Value
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }

    internal var uInt16: UInt16? {
        get {
            return self.number?.uint16Value
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object =  NSNull()
            }
        }
    }

    internal var uInt16Value: UInt16 {
        get {
            return self.numberValue.uint16Value
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }

    internal var int32: Int32? {
        get {
            return self.number?.int32Value
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object =  NSNull()
            }
        }
    }

    internal var int32Value: Int32 {
        get {
            return self.numberValue.int32Value
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }

    internal var uInt32: UInt32? {
        get {
            return self.number?.uint32Value
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object =  NSNull()
            }
        }
    }

    internal var uInt32Value: UInt32 {
        get {
            return self.numberValue.uint32Value
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }

    internal var int64: Int64? {
        get {
            return self.number?.int64Value
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object =  NSNull()
            }
        }
    }

    internal var int64Value: Int64 {
        get {
            return self.numberValue.int64Value
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }

    internal var uInt64: UInt64? {
        get {
            return self.number?.uint64Value
        }
        set {
            if let newValue = newValue {
                self.object = NSNumber(value: newValue)
            } else {
                self.object =  NSNull()
            }
        }
    }

    internal var uInt64Value: UInt64 {
        get {
            return self.numberValue.uint64Value
        }
        set {
            self.object = NSNumber(value: newValue)
        }
    }
}

//MARK: - Comparable
extension JSON : Swift.Comparable {}

internal func ==(lhs: JSON, rhs: JSON) -> Bool {

    switch (lhs.type, rhs.type) {
    case (.number, .number):
        return lhs.rawNumber == rhs.rawNumber
    case (.string, .string):
        return lhs.rawString == rhs.rawString
    case (.bool, .bool):
        return lhs.rawBool == rhs.rawBool
    case (.array, .array):
        return lhs.rawArray as NSArray == rhs.rawArray as NSArray
    case (.dictionary, .dictionary):
        return lhs.rawDictionary as NSDictionary == rhs.rawDictionary as NSDictionary
    case (.null, .null):
        return true
    default:
        return false
    }
}

internal func <=(lhs: JSON, rhs: JSON) -> Bool {

    switch (lhs.type, rhs.type) {
    case (.number, .number):
        return lhs.rawNumber <= rhs.rawNumber
    case (.string, .string):
        return lhs.rawString <= rhs.rawString
    case (.bool, .bool):
        return lhs.rawBool == rhs.rawBool
    case (.array, .array):
        return lhs.rawArray as NSArray == rhs.rawArray as NSArray
    case (.dictionary, .dictionary):
        return lhs.rawDictionary as NSDictionary == rhs.rawDictionary as NSDictionary
    case (.null, .null):
        return true
    default:
        return false
    }
}

internal func >=(lhs: JSON, rhs: JSON) -> Bool {

    switch (lhs.type, rhs.type) {
    case (.number, .number):
        return lhs.rawNumber >= rhs.rawNumber
    case (.string, .string):
        return lhs.rawString >= rhs.rawString
    case (.bool, .bool):
        return lhs.rawBool == rhs.rawBool
    case (.array, .array):
        return lhs.rawArray as NSArray == rhs.rawArray as NSArray
    case (.dictionary, .dictionary):
        return lhs.rawDictionary as NSDictionary == rhs.rawDictionary as NSDictionary
    case (.null, .null):
        return true
    default:
        return false
    }
}

internal func >(lhs: JSON, rhs: JSON) -> Bool {

    switch (lhs.type, rhs.type) {
    case (.number, .number):
        return lhs.rawNumber > rhs.rawNumber
    case (.string, .string):
        return lhs.rawString > rhs.rawString
    default:
        return false
    }
}

internal func <(lhs: JSON, rhs: JSON) -> Bool {

    switch (lhs.type, rhs.type) {
    case (.number, .number):
        return lhs.rawNumber < rhs.rawNumber
    case (.string, .string):
        return lhs.rawString < rhs.rawString
    default:
        return false
    }
}

private let trueNumber = NSNumber(value: true)
private let falseNumber = NSNumber(value: false)
private let trueObjCType = String(cString: trueNumber.objCType)
private let falseObjCType = String(cString: falseNumber.objCType)

// MARK: - NSNumber: Comparable

extension NSNumber {
    var isBool:Bool {
        get {
            let objCType = String(cString: self.objCType)
            if (self.compare(trueNumber) == .orderedSame && objCType == trueObjCType) || (self.compare(falseNumber) == .orderedSame && objCType == falseObjCType){
                return true
            } else {
                return false
            }
        }
    }
}

func ==(lhs: NSNumber, rhs: NSNumber) -> Bool {
    switch (lhs.isBool, rhs.isBool) {
    case (false, true):
        return false
    case (true, false):
        return false
    default:
        return lhs.compare(rhs) == .orderedSame
    }
}

func !=(lhs: NSNumber, rhs: NSNumber) -> Bool {
    return !(lhs == rhs)
}

func <(lhs: NSNumber, rhs: NSNumber) -> Bool {

    switch (lhs.isBool, rhs.isBool) {
    case (false, true):
        return false
    case (true, false):
        return false
    default:
        return lhs.compare(rhs) == .orderedAscending
    }
}

func >(lhs: NSNumber, rhs: NSNumber) -> Bool {

    switch (lhs.isBool, rhs.isBool) {
    case (false, true):
        return false
    case (true, false):
        return false
    default:
        return lhs.compare(rhs) == ComparisonResult.orderedDescending
    }
}

func <=(lhs: NSNumber, rhs: NSNumber) -> Bool {

    switch (lhs.isBool, rhs.isBool) {
    case (false, true):
        return false
    case (true, false):
        return false
    default:
        return lhs.compare(rhs) != .orderedDescending
    }
}

func >=(lhs: NSNumber, rhs: NSNumber) -> Bool {

    switch (lhs.isBool, rhs.isBool) {
    case (false, true):
        return false
    case (true, false):
        return false
    default:
        return lhs.compare(rhs) != .orderedAscending
    }
}
