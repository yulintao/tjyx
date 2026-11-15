import SwiftUI
import Foundation
import UIKit


public struct LegalDocumentSheet: View {
    public let title: String
    public let bodyText: String
    @Environment(\.presentationMode) private var presentationMode

    public init(title: String, bodyText: String) {
        self.title = title
        self.bodyText = bodyText
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                Text(bodyText)
                    .adaptiveFont(size: 13)
                    .foregroundColor(.primary)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .navigationBarTitle(title, displayMode: .inline)
            .navigationBarItems(trailing: Button(LocalizationManager.shared.t("done")) {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
