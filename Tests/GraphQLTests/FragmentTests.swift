import Testing
import Foundation
@testable import GraphQL

@Suite("Fragment Tests")
struct FragmentTests {

    // MARK: - Scalar Types

    @Test func scalarOnlyStruct() {
        struct Item: Codable {
            let id: String
            let count: Int
            let active: Bool
            let price: Double
        }
        #expect(FragmentResolver.fragment(for: Item.self) == "id count active price")
    }

    @Test func scalarFragmentableReturnEmpty() {
        #expect(String.fragment == "")
        #expect(Int.fragment == "")
        #expect(Bool.fragment == "")
        #expect(Double.fragment == "")
        #expect(URL.fragment == "")
        #expect(Date.fragment == "")
    }

    @Test func optionalScalarFields() {
        struct Profile: Codable {
            let name: String
            let nickname: String?
            let age: Int?
        }
        #expect(FragmentResolver.fragment(for: Profile.self) == "name nickname age")
    }

    // MARK: - Nested Types

    @Test func nestedFragmentable() {
        struct Address: Codable {
            let street: String
            let city: String
        }
        struct Person: Codable {
            let name: String
            let address: Address
        }
        #expect(FragmentResolver.fragment(for: Person.self) == "name address { street city }")
    }

    @Test func optionalNestedStruct() {
        #expect(FragmentResolver.fragment(for: UserWithProfile.self) == "id profile { bio }")
    }

    @Test func deepNesting() {
        struct Inner: Codable {
            let value: Int
        }
        struct Middle: Codable {
            let inner: Inner
        }
        struct Outer: Codable {
            let id: String
            let middle: Middle
        }
        #expect(FragmentResolver.fragment(for: Outer.self) == "id middle { inner { value } }")
    }

    // MARK: - Arrays

    @Test func arrayOfFragmentable() {
        struct Tag: Codable {
            let name: String
            let color: String
        }
        struct Article: Codable {
            let title: String
            let tags: [Tag]
        }
        #expect(FragmentResolver.fragment(for: Article.self) == "title tags { name color }")
    }

    @Test func arrayFragmentDelegates() {
        struct Point: Codable {
            let x: Double
            let y: Double
        }
        #expect(FragmentResolver.fragment(for: [Point].self) == "x y")
    }

    @Test func optionalArray() {
        struct Item: Codable {
            let value: Int
        }
        struct Container: Codable {
            let id: String
            let items: [Item]?
        }
        #expect(FragmentResolver.fragment(for: Container.self) == "id items { value }")
    }

    // MARK: - Enums

    @Test func enumProperty() {
        struct Task: Codable {
            let id: String
            let priority: Priority

            enum Priority: String, Codable, CaseIterable {
                case low, medium, high
            }
        }
        #expect(FragmentResolver.fragment(for: Task.self) == "id priority")
    }

    @Test func optionalEnum() {
        struct Event: Codable {
            let id: String
            let category: Category?

            enum Category: String, Codable, CaseIterable {
                case work, personal
            }
        }
        #expect(FragmentResolver.fragment(for: Event.self) == "id category")
    }

    @Test func nestedEnumFragment() {
        #expect(FragmentResolver.fragment(for: Post.self) == "id title status")
    }

    // MARK: - Generics

    @Test func genericFragment() {
        typealias EnergyChart = ChartResponse<EnergyPoint>
        #expect(FragmentResolver.fragment(for: EnergyChart.self) == "data { date value } name")
    }

    // MARK: - Mixed

    @Test func mixedOptionalAndRequired() {
        struct Node: Codable {
            let label: String
        }
        struct Graph: Codable {
            let id: String
            let root: Node
            let parent: Node?
            let children: [Node]
        }
        #expect(FragmentResolver.fragment(for: Graph.self) == "id root { label } parent { label } children { label }")
    }
}

// MARK: - Shared Test Structures

struct SimpleUser: Codable {
    let id: String
    let name: String
    let email: String
}

struct UserProfile: Codable {
    let bio: String
}

struct UserWithProfile: Codable {
    let id: String
    let profile: UserProfile?
}

struct ChartResponse<T: Codable>: Codable {
    let data: [T]
    let name: String
}

struct EnergyPoint: Codable {
    let date: Date
    let value: Int
}

struct Post: Codable {
    let id: String
    let title: String
    let status: Status

    enum Status: String, Codable, CaseIterable {
        case published
        case draft
    }
}
