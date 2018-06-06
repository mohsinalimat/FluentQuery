import Foundation
import Fluent

protocol FQPredicateValueProtocol : CustomStringConvertible, Equatable {
    var value: Any? { get }
}

public protocol FQPredicateGenericType: FQPart {
    var query: String { get }
}

public class FQJoinPredicate<T, U>: FQPart, FQPredicateGenericType where T: FQUniversalKeyPath, U: FQUniversalKeyPath {
    public var query: String
    
    public init(lhs: T, operation: FluentQueryPredicateOperator, rhs: U) {
        query = "\(lhs.queryValue) \(operation.rawValue) \(rhs.queryValue)"
    }
    
    //Aggreagate
    public init (lhs: FQAggregate.FunctionWithKeyPath<T>, operation: FluentQueryPredicateOperator, rhs: U) {
        query = "\(lhs.func) \(operation.rawValue) \(rhs.queryValue)"
    }
}

public class FQPredicate<T>: FQPart, FQPredicateGenericType  where T: FQUniversalKeyPath {
    public enum FQPredicateValue: FQPredicateValueProtocol {
        case simple(T.AType)
        case simpleOptional(T.AType?)
        case simpleAny(Any)
        case array([T.AType])
        case arrayOfOptionals([T.AType?])
        case arrayOfAny([Any])
        case string(String)
        
        public var description: String {
            let description: String
            switch self {
            case .simple:
                description = "simple"
            case .simpleOptional:
                description = "simpleOptional"
            case .simpleAny:
                description = "simpleAny"
            case .array:
                description = "array"
            case .arrayOfOptionals:
                description = "arrayOfOptionals"
            case .arrayOfAny:
                description = "arrayOfAny"
            case .string:
                description = "string"
            }
            return description
        }
        
        var value: Any? {
            let value: Any?
            switch self {
            case let .simple(v):
                value = v
            case let .simpleOptional(v):
                value = v
            case let .simpleAny(v):
                value = v
            case let .array(v):
                value = v
            case let .arrayOfOptionals(v):
                value = v
            case let .arrayOfAny(v):
                value = v
            case let .string(v):
                value = v
            }
            return value
        }
        
        public static func ==(lhs: FQPredicateValue, rhs: FQPredicateValue) -> Bool {
            return lhs.description == rhs.description
        }
    }
    var operation: FluentQueryPredicateOperator
    var value: FQPredicateValue
    var property: String
    public init (kp: T, operation: FluentQueryPredicateOperator, value: FQPredicateValue) {
        self.property = kp.queryValue
        self.operation = operation
        self.value = value
    }
    
    public init (kp func: FQAggregate.FunctionWithKeyPath<T>, operation: FluentQueryPredicateOperator, value: FQPredicateValue) {
        self.property = `func`.func
        self.operation = operation
        self.value = value
    }
    
    private func formatValue(_ v: Any?) -> String {
        guard let v = v else {
            return "NULL"
        }
        switch v {
        case is String:
            if let v = v as? String {
                if let first = v.first {
                    if "\(first)" == "(" {
                        return v
                    }
                }
            }
            return "'\(v)'"
        case is UUID: if let v = v as? UUID { return "'\(v.uuidString)'" } else { fallthrough }
        case is Bool: if let v = v as? Bool { return "\(v ? 1 : 0)" } else { fallthrough }
        case is Int: fallthrough
        case is Int8: fallthrough
        case is Int16: fallthrough
        case is Int32: fallthrough
        case is Int64: fallthrough
        case is UInt: fallthrough
        case is UInt8: fallthrough
        case is UInt16: fallthrough
        case is UInt32: fallthrough
        case is UInt64: fallthrough
        case is Float: fallthrough
        case is Double: return "\(v)"
        default: return "\(v)"
        }
    }
    
    public var query: String {
        var result = "\(property) \(operation.rawValue) "
        switch value {
        case .simpleAny(let v):
            result.append(formatValue(v))
        case .simple(let v):
            result.append(formatValue(v))
        case .simpleOptional(let v):
            result.append(formatValue(v))
        case .array(let v):
            result.append("(\(v.map { "\(formatValue($0))" }.joined(separator: ",")))")
        case .arrayOfOptionals(let v):
            result.append("(\(v.map { "\(formatValue($0))" }.joined(separator: ",")))")
        case .arrayOfAny(let v):
            result.append("(\(v.map { "\(formatValue($0))" }.joined(separator: ",")))")
        case .string(let v):
            result.append(formatValue(v))
        }
        return result
            .replacingOccurrences(of: "= NULL", with: "IS NULL")
            .replacingOccurrences(of: "!= NULL", with: "IS NOT NULL")
            .replacingOccurrences(of: "= nil", with: "IS NULL")
            .replacingOccurrences(of: "!= nil", with: "IS NOT NULL")
    }
}

// ==
public func == <T>(lhs: T, rhs:T.AType?) -> FQPredicateGenericType where T: FQUniversalKeyPath {
    return FQPredicate(kp: lhs, operation: .equal, value: .simpleOptional(rhs))
}
public func == <T>(lhs: T, rhs: T.AType) -> FQPredicateGenericType where T: FQUniversalKeyPath, T.AType: RawRepresentable {
    return FQPredicate(kp: lhs, operation: .equal, value: .simpleAny(rhs.rawValue))
}
// == for join
public func == <T, U>(lhs: T, rhs: U) -> FQPredicateGenericType where T: FQUniversalKeyPath, U: FQUniversalKeyPath {
    return FQJoinPredicate(lhs: lhs, operation: .equal, rhs: rhs)
}
// == aggregate function
public func == <M, K>(lhs: FQAggregate.FunctionWithKeyPath<M>, rhs: K) -> FQPredicateGenericType where M: FQUniversalKeyPath, K: Numeric {
    return FQPredicate(kp: lhs, operation: .equal, value: .simpleAny(rhs))
}
public func == <M>(lhs: FQAggregate.FunctionWithKeyPath<M>, rhs: FluentQuery) -> FQPredicateGenericType where M: FQUniversalKeyPath {
    return FQPredicate(kp: lhs, operation: .equal, value: .string("(\(rhs.query))"))
}
public func == <M, T>(lhs: FQAggregate.FunctionWithKeyPath<M>, rhs: T) -> FQPredicateGenericType where M: FQUniversalKeyPath, T: FQUniversalKeyPath {
    return FQJoinPredicate(lhs: lhs, operation: .equal, rhs: rhs)
}

// !=
public func != <T>(lhs: T, rhs: T.AType?) -> FQPredicateGenericType where T: FQUniversalKeyPath {
    return FQPredicate(kp: lhs, operation: .notEqual, value: .simpleOptional(rhs))
}
public func != <T>(lhs: T, rhs: T.AType) -> FQPredicateGenericType where T: FQUniversalKeyPath, T.AType: RawRepresentable {
    return FQPredicate(kp: lhs, operation: .notEqual, value: .simpleAny(rhs.rawValue))
}
// != for join
public func != <T, U>(lhs: T, rhs: U) -> FQPredicateGenericType where T: FQUniversalKeyPath, U: FQUniversalKeyPath {
    return FQJoinPredicate(lhs: lhs, operation: .notEqual, rhs: rhs)
}
// != aggregate function
public func != <M, K>(lhs: FQAggregate.FunctionWithKeyPath<M>, rhs: K) -> FQPredicateGenericType where M: FQUniversalKeyPath, K: Numeric {
    return FQPredicate(kp: lhs, operation: .notEqual, value: .simpleAny(rhs))
}
public func != <M>(lhs: FQAggregate.FunctionWithKeyPath<M>, rhs: FluentQuery) -> FQPredicateGenericType where M: FQUniversalKeyPath {
    return FQPredicate(kp: lhs, operation: .notEqual, value: .string("(\(rhs.query))"))
}
public func != <M, T>(lhs: FQAggregate.FunctionWithKeyPath<M>, rhs: T) -> FQPredicateGenericType where M: FQUniversalKeyPath, T: FQUniversalKeyPath {
    return FQJoinPredicate(lhs: lhs, operation: .notEqual, rhs: rhs)
}

// >
public func > <T>(lhs: T, rhs: T.AType?) -> FQPredicateGenericType where T: FQUniversalKeyPath {
    return FQPredicate(kp: lhs, operation: .greaterThan, value: .simpleOptional(rhs))
}
public func > <T>(lhs: T, rhs: T.AType) -> FQPredicateGenericType where T: FQUniversalKeyPath, T.AType: RawRepresentable {
    return FQPredicate(kp: lhs, operation: .greaterThan, value: .simpleAny(rhs.rawValue))
}
// > aggregate function
public func > <M, K>(lhs: FQAggregate.FunctionWithKeyPath<M>, rhs: K) -> FQPredicateGenericType where M: FQUniversalKeyPath, K: Numeric {
    return FQPredicate(kp: lhs, operation: .greaterThan, value: .simpleAny(rhs))
}
public func > <M>(lhs: FQAggregate.FunctionWithKeyPath<M>, rhs: FluentQuery) -> FQPredicateGenericType where M: FQUniversalKeyPath {
    return FQPredicate(kp: lhs, operation: .greaterThan, value: .string("(\(rhs.query))"))
}
public func > <M, T>(lhs: FQAggregate.FunctionWithKeyPath<M>, rhs: T) -> FQPredicateGenericType where M: FQUniversalKeyPath, T: FQUniversalKeyPath {
    return FQJoinPredicate(lhs: lhs, operation: .greaterThan, rhs: rhs)
}

// <
public func < <T>(lhs: T, rhs: T.AType?) -> FQPredicateGenericType where T: FQUniversalKeyPath {
    return FQPredicate(kp: lhs, operation: .lessThan, value: .simpleOptional(rhs))
}
public func < <T>(lhs: T, rhs: T.AType) -> FQPredicateGenericType where T: FQUniversalKeyPath, T.AType: RawRepresentable {
    return FQPredicate(kp: lhs, operation: .lessThan, value: .simpleAny(rhs.rawValue))
}
// < aggregate function
public func < <M, K>(lhs: FQAggregate.FunctionWithKeyPath<M>, rhs: K) -> FQPredicateGenericType where M: FQUniversalKeyPath, K: Numeric {
    return FQPredicate(kp: lhs, operation: .lessThan, value: .simpleAny(rhs))
}
public func < <M>(lhs: FQAggregate.FunctionWithKeyPath<M>, rhs: FluentQuery) -> FQPredicateGenericType where M: FQUniversalKeyPath {
    return FQPredicate(kp: lhs, operation: .lessThan, value: .string("(\(rhs.query))"))
}
public func < <M, T>(lhs: FQAggregate.FunctionWithKeyPath<M>, rhs: T) -> FQPredicateGenericType where M: FQUniversalKeyPath, T: FQUniversalKeyPath {
    return FQJoinPredicate(lhs: lhs, operation: .lessThan, rhs: rhs)
}

// >=
public func >= <T>(lhs: T, rhs: T.AType?) -> FQPredicateGenericType where T: FQUniversalKeyPath {
    return FQPredicate(kp: lhs, operation: .greaterThanOrEqual, value: .simpleOptional(rhs))
}
public func >= <T>(lhs: T, rhs: T.AType) -> FQPredicateGenericType where T: FQUniversalKeyPath, T.AType: RawRepresentable {
    return FQPredicate(kp: lhs, operation: .greaterThanOrEqual, value: .simpleAny(rhs.rawValue))
}
// >= aggregate function
public func >= <M, K>(lhs: FQAggregate.FunctionWithKeyPath<M>, rhs: K) -> FQPredicateGenericType where M: FQUniversalKeyPath, K: Numeric {
    return FQPredicate(kp: lhs, operation: .greaterThanOrEqual, value: .simpleAny(rhs))
}
public func >= <M>(lhs: FQAggregate.FunctionWithKeyPath<M>, rhs: FluentQuery) -> FQPredicateGenericType where M: FQUniversalKeyPath {
    return FQPredicate(kp: lhs, operation: .greaterThanOrEqual, value: .string("(\(rhs.query))"))
}
public func >= <M, T>(lhs: FQAggregate.FunctionWithKeyPath<M>, rhs: T) -> FQPredicateGenericType where M: FQUniversalKeyPath, T: FQUniversalKeyPath {
    return FQJoinPredicate(lhs: lhs, operation: .greaterThanOrEqual, rhs: rhs)
}

// <=
public func <= <T>(lhs: T, rhs: T.AType?) -> FQPredicateGenericType where T: FQUniversalKeyPath {
    return FQPredicate(kp: lhs, operation: .lessThanOrEqual, value: .simpleOptional(rhs))
}
public func <= <T>(lhs: T, rhs: T.AType) -> FQPredicateGenericType where T: FQUniversalKeyPath, T.AType: RawRepresentable {
    return FQPredicate(kp: lhs, operation: .lessThanOrEqual, value: .simpleAny(rhs.rawValue))
}

// <= aggregate function
public func <= <M, K>(lhs: FQAggregate.FunctionWithKeyPath<M>, rhs: K) -> FQPredicateGenericType where M: FQUniversalKeyPath, K: Numeric {
    return FQPredicate(kp: lhs, operation: .lessThanOrEqual, value: .simpleAny(rhs))
}
public func <= <M>(lhs: FQAggregate.FunctionWithKeyPath<M>, rhs: FluentQuery) -> FQPredicateGenericType where M: FQUniversalKeyPath {
    return FQPredicate(kp: lhs, operation: .lessThanOrEqual, value: .string("(\(rhs.query))"))
}
public func <= <M, T>(lhs: FQAggregate.FunctionWithKeyPath<M>, rhs: T) -> FQPredicateGenericType where M: FQUniversalKeyPath, T: FQUniversalKeyPath {
    return FQJoinPredicate(lhs: lhs, operation: .lessThanOrEqual, rhs: rhs)
}

// IN
public func ~~ <T>(lhs: T, rhs: [T.AType?]) -> FQPredicateGenericType where T: FQUniversalKeyPath {
    return FQPredicate(kp: lhs, operation: .in, value: .arrayOfOptionals(rhs))
}
public func ~~ <T>(lhs: T, rhs: [T.AType]) -> FQPredicateGenericType where T: FQUniversalKeyPath, T.AType: RawRepresentable {
    return FQPredicate(kp: lhs, operation: .in, value: .arrayOfAny(rhs.map { $0.rawValue }))
}
// IN SUBQUERY
public func ~~ <T>(lhs: T, rhs: FluentQuery) -> FQPredicateGenericType where T: FQUniversalKeyPath {
    return FQPredicate(kp: lhs, operation: .in, value: .string("(\(rhs.query))"))
}
// IN aggregate function
public func ~~ <M, K>(lhs: FQAggregate.FunctionWithKeyPath<M>, rhs: [K]) -> FQPredicateGenericType where M: FQUniversalKeyPath, K: Numeric {
    return FQPredicate(kp: lhs, operation: .in, value: .arrayOfAny(rhs))
}
public func ~~ <M>(lhs: FQAggregate.FunctionWithKeyPath<M>, rhs: FluentQuery) -> FQPredicateGenericType where M: FQUniversalKeyPath {
    return FQPredicate(kp: lhs, operation: .in, value: .string("(\(rhs.query))"))
}

// NOT IN
public func !~ <T>(lhs: T, rhs: [T.AType?]) -> FQPredicateGenericType where T: FQUniversalKeyPath {
    return FQPredicate(kp: lhs, operation: .notIn, value: .arrayOfOptionals(rhs))
}
public func !~ <T>(lhs: T, rhs: [T.AType]) -> FQPredicateGenericType where T: FQUniversalKeyPath, T.AType: RawRepresentable {
    return FQPredicate(kp: lhs, operation: .notIn, value: .arrayOfAny(rhs.map { $0.rawValue }))
}
// NOT IN SUBQUERY
public func !~ <T>(lhs: T, rhs: FluentQuery) -> FQPredicateGenericType where T: FQUniversalKeyPath {
    return FQPredicate(kp: lhs, operation: .notIn, value: .string("(\(rhs.query))"))
}
// NOT IN aggregate function
public func !~ <M, K>(lhs: FQAggregate.FunctionWithKeyPath<M>, rhs: [K]) -> FQPredicateGenericType where M: FQUniversalKeyPath, K: Numeric {
    return FQPredicate(kp: lhs, operation: .notIn, value: .arrayOfAny(rhs))
}
public func !~ <M>(lhs: FQAggregate.FunctionWithKeyPath<M>, rhs: FluentQuery) -> FQPredicateGenericType where M: FQUniversalKeyPath {
    return FQPredicate(kp: lhs, operation: .notIn, value: .string("(\(rhs.query))"))
}

// LIKE
infix operator ~=
public func ~= <T>(lhs: T, rhs: T.AType) -> FQPredicateGenericType where T: FQUniversalKeyPath {
    return FQPredicate(kp: lhs, operation: .like, value: .string("%\(rhs)"))
}
infix operator =~
public func =~ <T>(lhs: T, rhs: T.AType) -> FQPredicateGenericType where T: FQUniversalKeyPath {
    return FQPredicate(kp: lhs, operation: .like, value: .string("\(rhs)%"))
}
public func ~~ <T>(lhs: T, rhs: T.AType) -> FQPredicateGenericType where T: FQUniversalKeyPath {
    return FQPredicate(kp: lhs, operation: .like, value: .string("%\(rhs)%"))
}

// NOT LIKE
infix operator !~=
public func !~= <T>(lhs: T, rhs: T.AType) -> FQPredicateGenericType where T: FQUniversalKeyPath {
    return FQPredicate(kp: lhs, operation: .notLike, value: .string("%\(rhs)"))
}
infix operator !=~
public func !=~ <T>(lhs: T, rhs: T.AType) -> FQPredicateGenericType where T: FQUniversalKeyPath {
    return FQPredicate(kp: lhs, operation: .notLike, value: .string("\(rhs)%"))
}
infix operator !~~
public func !~~ <T>(lhs: T, rhs: T.AType) -> FQPredicateGenericType where T: FQUniversalKeyPath {
    return FQPredicate(kp: lhs, operation: .notLike, value: .string("%\(rhs)%"))
}

//FUTURE: create method which can handle two predicates
//FUTURE: generate paths like this `(r."carEquipment"->>'interior')::uuid` with type casting