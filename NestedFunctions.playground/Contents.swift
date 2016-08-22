//: Playground - noun: a place where people can play

import UIKit

var str = "Hello, playground"

typealias FBOject        = AnyObject
typealias FBDictionary   = [String: FBOject]
typealias FBArray        = [FBOject]

func resultFromOptional<A>(optional: A?, error: NSError) -> Result<A> {
    guard let a = optional else { return .Error(error) }
    return .Value(a)
}

protocol FBDecodable {
    static func Decode(object: FBOject?) -> Self?
}

extension FBDecodable {
    
    static private var snapError: NSError { return NSError(domain: "tbnb", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not convert snapshot to type user"]) }
    
    static func DecodeFBOject(object: FBOject?) -> Result<Self> {
        return resultFromOptional(Self.Decode(object), error: snapError)
    }
}


protocol Dumpable {}

extension Dumpable {
    func dump_() {
        print("----- \(Self.self) Dump -----")
        dump(self)
    }
}

enum Result<A> {
    case Error(NSError)
    case Value(A)
    
//    init(_ error: NSError) { self = Error(error) }
//    init(_ value: A)       { self = .Value(value) }
    
    init(_ error: NSError?, _ value: A) {
        if let error = error {
            self = .Error(error)
        } else {
            self = .Value(value)
        }
    }
}


func curry<A, B>(f: (A) -> B) -> A -> B {
    return { (a: A) -> B in f(a) }
}

func curry<A, B, C>(f: (A, B) -> C) -> A -> B -> C {
    return { a -> B -> C in { b -> C in f(a, b) } }
}

func curry<A, B, C, D>(f: (A, B, C) -> D) -> A -> B -> C -> D {
    return { a -> B -> C -> D in { b -> C -> D in { c -> D in f(a, b, c) } } }
}

func curry<A, B, C, D, E>(f: (A, B, C, D) -> E) -> A -> B -> C -> D -> E {
    return { a -> B -> C -> D -> E in { b -> C -> D -> E in { c -> D -> E in { d -> E in f(a, b, c, d) } } } }
}

infix operator >>> { associativity left precedence 150 }
infix operator <^> { associativity left }
infix operator <*> { associativity left }
infix operator <|  { associativity left precedence 150 }
infix operator <|? { associativity left precedence 150 }

func >>> <A, B>(a: A?, f: A -> B?) -> B? {
    guard let a = a else { return nil }
    return f(a)
}

func >>> <A, B>(a: Result<A>, f: A -> Result<B>) -> Result<B> {
    switch a {
    case let .Value(x):     return f(x)
    case let .Error(error): return .Error(error)
    }
}

func <^> <A, B>(f: A -> B, a: A?) -> B? {
    guard let a = a else { return nil }
    return f(a)
}

func <*> <A, B>(f: (A -> B)?, a: A?) -> B? {
    guard let f = f else { return nil }
    return f <^> a
}

func <| <A: FBDecodable>(dict: FBDictionary, key: String) -> A? {
    return dict[key] >>> FBParse
}

func <|? <A>(dict: FBDictionary, key: String) -> A?? {
    return pure(dict[key] >>> FBParse)
}

func <| <A>(dict: FBDictionary?, key: String) -> A? {
    return dict >>> { $0 <| key }
}

//func <|? <A>(dict: FBDictionary?, key: String) -> A? {
//    return pure(dict >>> { $0 <|? key })!
//}

func <| <A>(dict: FBDictionary, key: String) -> [A]? {
    return dict <| key >>> { (array: FBArray) in array.map { $0 >>> FBParse } >>> flatten }
}

func pure<A>(a: A) -> A? {
    return .Some(a)
}

func FBParse<A>(object: FBOject?) -> A? {
    return object as? A
}

func FBParse<A: FBDecodable>(object: FBOject) -> A? {
    return A.Decode(object)
}

func flatten<A>(array: [A?]) -> [A] {
    var list: [A] = []
    for item in array {
        guard let item = item else { continue }
        list.append(item)
    }
    return list
}

extension NSError: Dumpable{}

extension String: FBDecodable {
    static func Decode(object: FBOject?) -> String? {
        return object as? String
    }
}

extension Int: FBDecodable {
    static func Decode(object: FBOject?) -> Int? {
        return object as? Int
    }
}

extension Double: FBDecodable {
    static func Decode(object: FBOject?) -> Double? {
        return object as? Double
    }
}


func extract<A>(dict: FBDictionary, _ key: String) -> A? {
    return dict[key] >>> FBParse
}

func extractPure<A>(dict: FBDictionary, _ key: String) -> A?? {
    return pure(dict[key] >>> FBParse)
}


struct User: Dumpable, FBDecodable {
    let key:        String
    let username:   String?
    let rating:     Double?
    let friendName: String
    
    static func Decode(object: FBOject?) -> User? {
         return FBParse(object) >>> {
            curry(User.init)
                <^> $0 <| "key"
                <*> $0 <|? "username"
                <*> $0 <|? "rating"
                <*> $0 <|  "friend" <| "username"
        }
    }
}


struct Meal: Dumpable, FBDecodable {
    let key:   String
    let cost:  Double
    let feeds: Int

    static func Decode(object: FBOject?) -> Meal? {
        return FBParse(object) >>> {
             curry(Meal.init)
                <^> $0 <| "key"
                <*> $0 <| "cost"
                <*> $0 <| "feeds"
        }
    }
}

extension Meal {
    subscript(attendees: Meal) -> User? {
        return nil
    }
}


let userDict: FBDictionary? = ["key" : "user1", "username" : "keneLarge", "rating" : 1.5, "friend" : ["key": "user2", "username" : "billyBob"]]
let mealDict: FBDictionary? = ["key" : "meal1", "cost" : 8.34, "feeds" : 5]

let userDictKeyOnly: FBDictionary? = ["key" : "user1"]

let userDictNestedDict: FBDictionary? = ["key": "user1", "username": "kenelarge", "friend" : ["key": "user2", "username" : "billyBob"], "rating" : 3.5]


let fakeDict = [1 : 1, 2 : 2]

func getUser(withResult: Result<User> -> Void) {
    withResult(User.DecodeFBOject(userDict))
}

func getMeal(withResult: Result<Meal> -> Void) {
    withResult(Meal.DecodeFBOject(mealDict))
}


getMeal { result in
    switch result {
    case let .Error(error): error.dump_()
    case let .Value(meal):  meal.dump_()
    }
}

getUser { result in
    switch result {
    case let .Error(error): error.dump_()
    case let .Value(user):  user.dump_()
    }
}










