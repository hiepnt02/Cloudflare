//
//  Quick3DTests.swift
//  Quick3DTests
//
//  Created by Pham Thanh Xuan on 15/05/2023.
//
//  QUICK-971: file này đã bị gỡ khỏi Sources của target Quick3DTests. Nó tham chiếu
//  `ContentView`, `GridCell` và `Inspection` — cả ba đã bị xoá khỏi app từ lâu — nên nó làm
//  cả target không compile được, tức là trước đây không có test nào chạy được.
//  Muốn khôi phục: dựng lại ba kiểu trên rồi thêm file này lại vào build phase Sources.
//

import XCTest
import ViewInspector
import SwiftUI
@testable import Quick3D

extension Inspection: InspectionEmissary {}

final class Quick3DTests: XCTestCase {
    @ObservedObject var productData = ProductData()
    @ObservedObject var userManager = UserManager()
    private var isIPhone: Bool {
        UIDevice.current.isIphone
    }

    private func contentView() -> ContentView {
        ContentView(navigateToProjectDetail: .constant(false), navigateCat: .constant(nil))
    }

    private func projectListView() -> ProjectListView {
        ProjectListView(isEditing: .constant(false), isShowConfirmDelete: .constant(false), isShowRenameAlert: .constant(false), isProductDetailActive: .constant(false), isShowSingleDeletePopup: .constant(false), isShowExportComplete: .constant(false), isLoading: .constant(false), selectedItem: .constant([]), currentCat: .constant(nil), renameCat: .constant(Cat(userId: nil, id: "", title: "", folderName: "",jobsiteId: "", createDate: "", createTime: "", sourceStr: "")), deleteCat: .constant(nil))
    }

    func testStatusViewAppear() throws {
        let sut = contentView()
        let exp = sut.inspection.inspect { view in
            let text = try view.actualView().inspect().find(viewWithTag: 30).text().string()
            XCTAssertEqual(text, Status.all.rawValue.localized(self.userManager.userLanguage))
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        self.wait(for: [exp], timeout: 1.0)
    }

    func testChangeStatusToUploadComplete() throws {
        let sut = contentView()
        let exp = sut.inspection.inspect { view in
            let menu = try view.actualView().inspect().find(viewWithTag: 4).menu()
            try menu.find(button: Status.uploadCompleted.rawValue.localized(self.userManager.userLanguage)).tap()
            let label = try view.actualView().selectedStatus
            XCTAssertEqual(label, Status.uploadCompleted)
        }
        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 0.1)
    }

    func testChangeStatusToSFMProcessing() throws {
        let sut = contentView()
        let exp = sut.inspection.inspect { view in
            let menu = try view.actualView().inspect().find(viewWithTag: 4).menu()
            try menu.find(button: Status.sfmProcessing.rawValue.localized(self.userManager.userLanguage)).tap()
            let label = try view.actualView().selectedStatus
            XCTAssertEqual(label, Status.sfmProcessing)
        }
        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 0.1)
    }

    func testChangeStatusToTransformationCompleted() throws {
        let sut = contentView()
        let exp = sut.inspection.inspect { view in
            let menu = try view.actualView().inspect().find(viewWithTag: 4).menu()
            try menu.find(button: Status.transformationCompleted.rawValue.localized(self.userManager.userLanguage)).tap()
            let label = try view.actualView().selectedStatus
            XCTAssertEqual(label, Status.transformationCompleted)
        }
        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 0.1)
    }

    func testChangeStatusToVerificationCompleted() throws {
        let sut = contentView()
        let exp = sut.inspection.inspect { view in
            let menu = try view.actualView().inspect().find(viewWithTag: 4).menu()
            try menu.find(button: Status.verificationCompleted.rawValue.localized(self.userManager.userLanguage)).tap()
            let label = try view.actualView().selectedStatus
            XCTAssertEqual(label, Status.verificationCompleted)
        }
        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 0.1)
    }

    func testSearchResult() throws {
        let sut = contentView()
        productData.fetchLocalProjectList()
        let exp = sut.inspection.inspect { view in
            let text = try view.actualView().inspect().find(viewWithTag: 5).text().string()
            XCTAssertEqual(text, String(format: "SEARCH_RESULTS".localized(self.userManager.userLanguage), 80, 750))
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 2)
    }

    func testProjectListCount() throws {
        let sut = projectListView()
        productData.fetchLocalProjectList()
        let exp = sut.inspection.inspect { view in
            let cells = try view.actualView().inspect().findAll(GridCell.self)
            XCTAssertEqual(cells.count, 80)
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 2)
    }

    func testProjectTitle() throws {
        let sut = projectListView()
        productData.fetchLocalProjectList()
        let exp = sut.inspection.inspect { view in
            let firstCell = try view.actualView().inspect().findAll(GridCell.self).first
            let text = try firstCell?.find(viewWithTag: 6).text().string()
            XCTAssertEqual(text, "Test0331")
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 2)
    }

    func testProjectUploadDate() throws {
        let sut = projectListView()
        productData.fetchLocalProjectList()
        let exp = sut.inspection.inspect { view in
            let firstCell = try view.actualView().inspect().findAll(GridCell.self).first
            let text = try firstCell?.find(viewWithTag: 7).text().string()
            XCTAssertEqual(text, self.userManager.userLanguage == LanguageMode.ja.rawValue ? "2023/02/21" : "21/02/2023")
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 2)
    }

    func testProjectUploadTime() throws {
        let sut = projectListView()
        productData.fetchLocalProjectList()
        let exp = sut.inspection.inspect { view in
            let firstCell = try view.actualView().inspect().findAll(GridCell.self).first
            let text = try firstCell?.find(viewWithTag: 8).text().string()
            XCTAssertEqual(text, "15:22")
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 2)
    }

    func testProjectJobsite() throws {
        let sut = projectListView()
        productData.fetchLocalProjectList()
        productData.fetchLocalJobSite()
        let exp = sut.inspection.inspect { view in
            let firstCell = try view.actualView().inspect().findAll(GridCell.self).first
            let text = try firstCell?.find(viewWithTag: 9).text().string()
            XCTAssertEqual(text, "Q3Dテスト0607")
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 2)
    }

    func testProjectUserName() throws {
        let sut = projectListView()
        productData.fetchLocalProjectList()
        productData.fetchLocalUserList()
        let exp = sut.inspection.inspect { view in
            let firstCell = try view.actualView().inspect().findAll(GridCell.self).first
            let text = try firstCell?.find(viewWithTag: 10).text().string()
            XCTAssertEqual(text, "Nishimura Landlog")
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 2)
    }

    func testProjectStatus() throws {
        let sut = projectListView()
        productData.fetchLocalProjectList()
        let exp = sut.inspection.inspect { view in
            let firstCell = try view.actualView().inspect().findAll(GridCell.self).first
            let text = try firstCell?.find(viewWithTag: 11).text().string()
            XCTAssertEqual(text, "PROCESSING_DONE".localized(self.userManager.userLanguage))
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 2)
    }

    func testProjectStatusImage() throws {
        let sut = projectListView()
        productData.fetchLocalProjectList()
        let exp = sut.inspection.inspect { view in
            let firstCell = try view.actualView().inspect().findAll(GridCell.self).first
            let img1 = try firstCell?.find(viewWithTag: 12).image().actualImage().name()
            XCTAssertEqual(img1, "check")
            let img2 = try firstCell?.find(viewWithTag: 13).image().actualImage().name()
            XCTAssertEqual(img2, "check")
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 2)
    }

    func testShootWarningButton() throws {
        let sut = contentView()
        let exp = sut.inspection.inspect { view in
            let imgName = try view.actualView().inspect().find(viewWithTag: 18).button().labelView().image().actualImage().name()
            XCTAssertEqual(imgName, "cameraButton2")
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 0.1)
    }

    func testDisplayShootWarningPopup() throws {
        let sut = contentView()
        let exp = sut.inspection.inspect { view in
            try view.actualView().inspect().find(viewWithTag: 18).button().tap()
            let popup = try view.actualView().inspect().find(viewWithTag: 19)
            XCTAssertNotNil(popup)
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 0.1)
    }

    func testShootWarningPopupTitle() throws {
        let sut = contentView()
        let exp = sut.inspection.inspect { view in
            try view.actualView().inspect().find(viewWithTag: 18).button().tap()
            let text = try view.actualView().inspect().find(viewWithTag: 19).find(viewWithTag: 0).text().string()
            XCTAssertEqual(text, "SHOOT_WARNING_TITLE".localized(self.userManager.userLanguage))
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 0.1)
    }

    func testShootWarningPopupMessage() throws {
        let sut = contentView()
        let exp = sut.inspection.inspect { view in
            try view.actualView().inspect().find(viewWithTag: 18).button().tap()
            let text = try view.actualView().inspect().find(viewWithTag: 19).find(viewWithTag: 1).text().string()
            XCTAssertEqual(text, "SHOOT_WARNING_MESSAGE".localized(self.userManager.userLanguage))
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 0.1)
    }

    func testShootWarningPopupNote() throws {
        let sut = contentView()
        let exp = sut.inspection.inspect { view in
            try view.actualView().inspect().find(viewWithTag: 18).button().tap()
            let text = try view.actualView().inspect().find(viewWithTag: 19).find(viewWithTag: 2).text().string()
            XCTAssertEqual(text, "SHOOT_WARNING_NOTE".localized(self.userManager.userLanguage))
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 0.1)
    }

    func testShootWarningPopupCancelButton() throws {
        let sut = contentView()
        let exp = sut.inspection.inspect { view in
            try view.actualView().inspect().find(viewWithTag: 18).button().tap()
            let text = try view.actualView().inspect().find(viewWithTag: 19).find(viewWithTag: 3).button().labelView().text().string()
            XCTAssertEqual(text, "CANCEL".localized(self.userManager.userLanguage))
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 0.1)
    }

    func testShootWarningPopupOKButton() throws {
        let sut = contentView()
        let exp = sut.inspection.inspect { view in
            try view.actualView().inspect().find(viewWithTag: 18).button().tap()
            let text = try view.actualView().inspect().find(viewWithTag: 19).find(viewWithTag: 4).button().labelView().text().string()
            XCTAssertEqual(text, "ShootWarningOK".localized(self.userManager.userLanguage))
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 0.1)
    }

    func testShootWarningPopupAttribute() throws {
        let sut = contentView()
        let exp = sut.inspection.inspect { view in
            try view.actualView().inspect().find(viewWithTag: 18).button().tap()
            let popup = try view.actualView().inspect().find(viewWithTag: 19).zStack().vStack(1)
            let padding = try popup.padding(.horizontal)
            XCTAssertEqual(padding, self.isIPhone ? 20 : 30)
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 0.1)
    }

    func testDisplayGroupView() {
        let sut = contentView()
        let exp = sut.inspection.inspect { view in
            let groupView = try view.actualView().inspect().find(viewWithTag: 21).picker()
            XCTAssertNotNil(groupView)
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 0.1)
    }

    func testGroupViewTitle() {
        let sut = contentView()
        let exp = sut.inspection.inspect { view in
            let year = try view.actualView().inspect().find(viewWithTag: 21).find(viewWithTag: 0).text().string()
            XCTAssertEqual(year, GroupMode.year.title.localized(self.userManager.userLanguage))

            let month = try view.actualView().inspect().find(viewWithTag: 21).find(viewWithTag: 1).text().string()
            XCTAssertEqual(month, GroupMode.month.title.localized(self.userManager.userLanguage))

            let day = try view.actualView().inspect().find(viewWithTag: 21).find(viewWithTag: 2).text().string()
            XCTAssertEqual(day, GroupMode.day.title.localized(self.userManager.userLanguage))
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 0.1)
    }

    func testDisplaySearchView() {
        let sut = contentView()
        let exp = sut.inspection.inspect { view in
            let view = try view.actualView().inspect().find(viewWithTag: 22)
            XCTAssertNotNil(view)
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 0.1)
    }

    func testSearchViewIcon() {
        let sut = contentView()
        let exp = sut.inspection.inspect { view in
            let view = try view.actualView().inspect().find(viewWithTag: 22).hStack().button(0).labelView().image().actualImage().name()
            XCTAssertEqual(view, "search")
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 0.1)
    }

    func testSearchViewPlaceholder() {
        let sut = contentView()
        let exp = sut.inspection.inspect { view in
            let view = try view.actualView().inspect().find(viewWithTag: 22).hStack().zStack(1).text(0).string()
            XCTAssertEqual(view, "JOBSITE_PROJECT_SEARCH".localized(self.userManager.userLanguage))
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 0.1)
    }

    func testSearchViewRemoveIcon() {
        let sut = contentView()
        let exp = sut.inspection.inspect { view in
            try view.actualView().inspect().find(viewWithTag: 22).hStack().zStack(1).textField(1).setInput("test")
            let button = try view.actualView().inspect().find(viewWithTag: 22).hStack().button(3)
            XCTAssertNotNil(button)
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 0.1)
    }

    func testDisplayFilterView() {
        let sut = contentView()
        let exp = sut.inspection.inspect { view in
            let view = try view.actualView().inspect().find(viewWithTag: 23)
            XCTAssertNotNil(view)
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 0.1)
    }

    func testFilterViewImage() {
        let sut = contentView()
        let exp = sut.inspection.inspect { view in
            let text = try view.actualView().inspect().find(viewWithTag: 23).button().labelView().image().actualImage().name()
            XCTAssertEqual(text, "filterSetting")
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 0.1)
    }

    func testDisplayFilterPopup() {
        let sut = contentView()
        let exp = sut.inspection.inspect { view in
            let popup = try view.actualView().inspect().find(viewWithTag: 24)
            XCTAssertNotNil(popup)
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 0.1)
    }

    func testFilterPopupTitle() {
        let sut = contentView()
        let exp = sut.inspection.inspect { view in
            try view.actualView().inspect().find(viewWithTag: 23).button().tap()
            let text = try view.actualView().inspect().find(viewWithTag: 24).find(viewWithTag: 0).text().string()
            XCTAssertEqual(text, "FILTER_TITLE".localized(self.userManager.userLanguage))
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 0.1)
    }

    func testFilterPopupCloseIcon() {
        let sut = contentView()
        let exp = sut.inspection.inspect { view in
            try view.actualView().inspect().find(viewWithTag: 23).button().tap()
            let text = try view.actualView().inspect().find(viewWithTag: 24).find(viewWithTag: 1).button().labelView().image().actualImage().name()
            XCTAssertEqual(text, "xmark")
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 0.1)
    }

    func testFilterPopupSaveOnTitle() {
        let sut = contentView()
        let exp = sut.inspection.inspect { view in
            try view.actualView().inspect().find(viewWithTag: 23).button().tap()
            let text = try view.actualView().inspect().find(viewWithTag: 24).find(viewWithTag: 2).text().string()
            XCTAssertEqual(text, "SAVED_ON".localized(self.userManager.userLanguage))
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 0.1)
    }

    func testFilterPopupChoosePhotographerTitle() {
        let sut = contentView()
        let exp = sut.inspection.inspect { view in
            try view.actualView().inspect().find(viewWithTag: 23).button().tap()
            let text = try view.actualView().inspect().find(viewWithTag: 24).find(viewWithTag: 3).text().string()
            XCTAssertEqual(text, "CHOOSE_PHOTOGRAPHER".localized(self.userManager.userLanguage))
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 0.1)
    }

    func testFilterPopupJobsite() {
        let sut = contentView()
        let exp = sut.inspection.inspect { view in
            try view.actualView().inspect().find(viewWithTag: 23).button().tap()
            let text = try view.actualView().inspect().find(viewWithTag: 24).find(viewWithTag: 4).text().string()
            XCTAssertEqual(text, "JOBSITE_NAME".localized(self.userManager.userLanguage))
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 0.1)
    }

    func testFilterPopupCancelButton() {
        let sut = contentView()
        let exp = sut.inspection.inspect { view in
            try view.actualView().inspect().find(viewWithTag: 23).button().tap()
            let text = try view.actualView().inspect().find(viewWithTag: 24).find(viewWithTag: 5).button().labelView().text().string()
            XCTAssertEqual(text, "CANCEL".localized(self.userManager.userLanguage))
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 0.1)
    }

    func testFilterPopupOKButton() {
        let sut = contentView()
        let exp = sut.inspection.inspect { view in
            try view.actualView().inspect().find(viewWithTag: 23).button().tap()
            let text = try view.actualView().inspect().find(viewWithTag: 24).find(viewWithTag: 6).button().labelView().text().string()
            XCTAssertEqual(text, "SEARCH".localized(self.userManager.userLanguage))
        }

        ViewHosting.host(view: sut
            .environmentObject(userManager)
            .environmentObject(productData)
        )
        wait(for: [exp], timeout: 0.1)
    }
}
