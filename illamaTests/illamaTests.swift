//
//  illamaTests.swift
//  illamaTests
//
//  Created by Jack Youstra on 8/2/23.
//

import XCTest
@testable import iLlama

final class illamaTests: XCTestCase {

    func testPerformanceExample() throws {
        var client: LlamaClient! = nil
        measure {
            client = LlamaClient.live
        }
        
        measure {
            client.run_query("talk to me: this is a story of them against us")
        }
        
        measure {
            client.run_query("Damn that's crazy")
        }
    }
}
