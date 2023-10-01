//
//  illamaUITests.swift
//  illamaUITests
//
//  Created by Jack Youstra on 8/2/23.
//

import XCTest

final class illamaUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
//        setupSnapshot(app)
        app.launchArguments += ["UI-Testing"]
        app.launch()
        
        
        let app = app2
        let sidebarCollectionView = app.collectionViews["Sidebar"]
        sidebarCollectionView/*@START_MENU_TOKEN@*/.staticTexts["Sep 11, 2023 at 1:48:36 AM"]/*[[".cells.staticTexts[\"Sep 11, 2023 at 1:48:36 AM\"]",".staticTexts[\"Sep 11, 2023 at 1:48:36 AM\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        app.navigationBars["My chat with Llama"].buttons["Back"].tap()
        app.navigationBars["_TtGC7SwiftUI32NavigationStackHosting"].buttons["Add Item"].tap()
        app.navigationBars["Sep 11, 2023 at 2:02:31 AM"].buttons["Back"].tap()
        
        let sep112023At20231AmStaticText = sidebarCollectionView/*@START_MENU_TOKEN@*/.staticTexts["Sep 11, 2023 at 2:02:31 AM"]/*[[".cells.staticTexts[\"Sep 11, 2023 at 2:02:31 AM\"]",".staticTexts[\"Sep 11, 2023 at 2:02:31 AM\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
        sep112023At20231AmStaticText/*@START_MENU_TOKEN@*/.press(forDuration: 1.3);/*[[".tap()",".press(forDuration: 1.3);"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
        
        let collectionViewsQuery = app.collectionViews
        collectionViewsQuery/*@START_MENU_TOKEN@*/.buttons["Rename"]/*[[".cells.buttons[\"Rename\"]",".buttons[\"Rename\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        
        let app2 = app
        app2.alerts["Rename"].scrollViews.otherElements.collectionViews/*@START_MENU_TOKEN@*/.textFields["Sep 11, 2023 at 2:02:31 AM"]/*[[".cells.textFields[\"Sep 11, 2023 at 2:02:31 AM\"]",".textFields[\"Sep 11, 2023 at 2:02:31 AM\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        app.alerts["Rename"].scrollViews.otherElements.buttons["OK"].tap()
        sep112023At20231AmStaticText.tap()
        
        let textView = app.children(matching: .window).element(boundBy: 0).children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .textView).element
        textView.tap()
        
        let arrowUpCircleButton = app.buttons["Arrow Up Circle"]
        arrowUpCircleButton.tap()
        textView.tap()
        app2.navigationBars["My chat with llama"]/*@START_MENU_TOKEN@*/.staticTexts["🄼↓"]/*[[".otherElements[\"🄼↓\"]",".buttons[\"🄼↓\"]",".buttons.staticTexts[\"🄼↓\"]",".staticTexts[\"🄼↓\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.tap()
        collectionViewsQuery/*@START_MENU_TOKEN@*/.buttons["Enhanced"]/*[[".cells.buttons[\"Enhanced\"]",".buttons[\"Enhanced\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        textView.tap()
        arrowUpCircleButton.tap()
        textView.tap()
        app.navigationBars["My chat with llama"].buttons["Back"].tap()
        
        let settingsSwitch = app2.navigationBars["_TtGC7SwiftUI32NavigationStackHosting"]/*@START_MENU_TOKEN@*/.switches["Settings"]/*[[".otherElements[\"Settings\"].switches[\"Settings\"]",".switches[\"Settings\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
        settingsSwitch.tap()
        settingsSwitch.tap()
        settingsSwitch.tap()
        settingsSwitch.tap()
        settingsSwitch.tap()
        
        
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
